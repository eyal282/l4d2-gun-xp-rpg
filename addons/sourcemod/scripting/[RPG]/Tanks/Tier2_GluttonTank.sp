
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
    name        = "Glutton Tank --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Glutton Tank that eats survivors.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int tankIndex;
int eatSurvivorIndex;

// [victim][attacker]
bool g_bEaten[MAXPLAYERS+1][MAXPLAYERS+1];
int g_iEatAttacker[MAXPLAYERS+1];

int g_iOldHealth[MAXPLAYERS+1];
int g_iOldMaxHealth[MAXPLAYERS+1];
bool g_bReleaseRandom[MAXPLAYERS+1];
bool g_bRoundLost;
float g_fLastOrigin[MAXPLAYERS+1][3];
int g_iCatchBot[MAXPLAYERS+1];

char g_sLastTankName[MAXPLAYERS+1][64];

float g_fVomitRadius = 128.0;

int g_iReleaseChance = 10;

float g_fNightmareDuration = 20.0;

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "RPG_Tanks"))
    {
        RegisterTank();
    }
}

public void OnConfigsExecuted()
{
    RegisterTank();
}

public void OnPluginEnd()
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;        

        else if(g_iEatAttacker[i] <= 0)
            continue;

        int tank = g_iEatAttacker[i];

        if(!g_bEaten[i][tank])
            continue;

        PlacePlayerOUTSIDETankBelly(i, tank);
    }
}

public void OnPluginStart()
{
    RegisterTank();

    HookEvent("player_now_it", Event_Boom, EventHookMode_Post);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_bot_replace", Event_BotReplacesAPlayer, EventHookMode_Post);
}

public Action Event_Boom(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;

	else if(!RPG_Tanks_IsTankInPlay(tankIndex))
		return Plugin_Continue;

	RPG_Perks_ApplyEntityTimedAttribute(victim, "Stun", 10.0, COLLISION_SET_IF_LOWER, ATTRIBUTE_NEGATIVE);

	return Plugin_Continue;
}

public Action Event_RoundStart(Handle hEvent, char[] Name, bool dontBroadcast)
{
    g_bRoundLost = false;

    return Plugin_Continue;
}


public Action Event_BotReplacesAPlayer(Handle event, const char[] name, bool dontBroadcast)
{
    int oldPlayer = GetClientOfUserId(GetEventInt(event, "player"));
    int newPlayer = GetClientOfUserId(GetEventInt(event, "bot"));

    g_iCatchBot[oldPlayer] = newPlayer;

    return Plugin_Continue;
}
public void GunXP_OnReloadRPGPlugins()
{
    for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(RPG_Tanks_GetClientTank(i) != tankIndex)
			continue;

		UC_PrintToChatRoot("Didn't reload Tier2_GluttonTank.smx because a Glutton Tank is alive.");
		return;
	}
    
    GunXP_ReloadPlugin();
}

public void RPG_Perks_OnZombiePlayerSpawned(int priority, int client, bool bApport)
{
    if(priority != 0)
        return;

    GetClientName(client, g_sLastTankName[client], sizeof(g_sLastTankName[]));

    RPG_Perks_ApplyEntityTimedAttribute(client, "Calc Most Processed Survivor", 0.1, COLLISION_SET, ATTRIBUTE_NEUTRAL);
}

public void RPG_Tanks_OnRPGTankCastActiveAbility(int client, int abilityIndex)
{  
    if(RPG_Tanks_GetClientTank(client) != tankIndex)
        return;

    if(abilityIndex == eatSurvivorIndex)
        CastEatSurvivor(client);
}
public void CastEatSurvivor(int client)
{
    int survivor1 = FindRandomSurvivorWithoutIncap(client, 256.0);

    if(survivor1 == -1)
    {
        for(int i=1;i <= MaxClients;i++)
        {
            if(!IsClientInGame(i))
                continue;

            else if(!IsPlayerAlive(i))
                continue;

            else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
                continue;

            RPG_Perks_ApplyEntityTimedAttribute(i, "Nightmare", g_fNightmareDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
        }

        UC_PrintToChatAll("The Tank couldn't find a survivor to eat.");
        UC_PrintToChatAll("The Tank triggered a NIGHTMARE for %.0f seconds.", g_fNightmareDuration);


        return;
    }

    PlacePlayerINSIDETankBelly(survivor1, client);

    int survivor2 = FindRandomSurvivorWithoutIncap(client, 256.0);

    if(survivor2 == -1)
    {
        PrintToChatAll("%N was Eaten by the Tank! Shove the Tank to release him!", survivor1);

        return;
    }

    PlacePlayerINSIDETankBelly(survivor2, client);

    PrintToChatAll("%N & %N were Eaten by the Tank!", survivor1, survivor2);
    PrintToChatAll("Shove the Tank to release them!");
}

public void L4D2_OnEntityShoved_Post(int client, int entity, int weapon, const float vecDir[3], bool bIsHighPounce)
{
    if(RPG_Perks_GetZombieType(entity) != ZombieType_Tank)
        return;

    else if(RPG_Tanks_GetClientTank(entity) != tankIndex)
        return;

    else if(GetRandomInt(1, 100) > g_iReleaseChance)
        return;

    else if(CountEatenSurvivors(entity) == 0)
        return;

    g_bReleaseRandom[entity] = true;

}
/*
public Action L4D_OnTakeOverBot(int client)
{
    int tank = g_iEatAttacker[client];

    PrintToChat(client, "Takeober");

    if(!g_bEaten[client][tank])
        return Plugin_Continue;

    g_iCatchBot[client] = 0;

    L4D_ReplaceWithBot(client);

    int bot = g_iCatchBot[client];

    if(bot != 0)
    {
        // Anti bug from L4D_ReplaceWithBot erasing it.
        g_iEatAttacker[client] = tank;

        ReplacePlayersFromTankBelly(client, bot);
    }
    
    return Plugin_Handled;
}
*/

public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
    if(!StrEqual(attributeName, "Eaten Alive"))
        return;

    else if(oldClient == newClient)
        return;

    ReplacePlayersFromTankBelly(oldClient, newClient);

}

public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
    if(strncmp(attributeName, "Glutton Instant Kill #", 22) == 0)
    {
        char sUserId[64];
        strcopy(sUserId, sizeof(sUserId), attributeName);
        ReplaceStringEx(sUserId, sizeof(sUserId), "Glutton Instant Kill #", "");

        int userid = StringToInt(sUserId);

        int tank = GetClientOfUserId(userid);
        
        TeleportEntity(entity, view_as<float>({ 32000, 32000, 32000 }), NULL_VECTOR, NULL_VECTOR);

        RPG_Perks_InstantKill(entity, tank, tank, DMG_ACID);

        if(IsPlayerAlive(entity))
            ForcePlayerSuicide(entity);

        return;
    }
    else if(StrEqual(attributeName, "Calc Most Processed Survivor"))
    {
        if(RPG_Perks_GetZombieType(entity) != ZombieType_Tank)
            return;

        else if(RPG_Tanks_GetClientTank(entity) != tankIndex)
            return;

        int count = 0;
        int mostProcessed = 0;

        for(int i=1;i <= MaxClients;i++)
        {
            if(!IsClientInGame(i))
                continue;        

            else if(!g_bEaten[i][entity])
                continue;

            count++;

            if(mostProcessed == 0 || float(g_iOldHealth[i]) / float(g_iOldMaxHealth[i]) < float(g_iOldHealth[mostProcessed]) / float(g_iOldMaxHealth[mostProcessed]))
            {
                mostProcessed = i;
            }
        }

        if(count == 0)
        {
            SetClientName(entity, g_sLastTankName[entity]);
        }
        else
        {
            char sName[64];
            FormatEx(sName, sizeof(sName), "(%.0f%%) %s", float(g_iOldHealth[mostProcessed]) / float(g_iOldMaxHealth[mostProcessed]) * 100.0, g_sLastTankName[entity]);

            SetClientName(entity, sName);
        }

        RPG_Perks_ApplyEntityTimedAttribute(entity, "Calc Most Processed Survivor", 0.1, COLLISION_SET, ATTRIBUTE_NEUTRAL);
    }
    if(!StrEqual(attributeName, "Eaten Alive"))
        return;

    int tank = g_iEatAttacker[entity];
    // Takeover...
    if(tank <= 0 || !g_bEaten[entity][tank])
        return;

    int count = 0;

    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;        

        else if(!IsPlayerAlive(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        count++;
    }
    
    if(count < 1)
    {
        g_bRoundLost = true;
    }

    if(g_bRoundLost)
    {
        ProcessClientInsideTank(entity);

        return;
    }
    if(g_bReleaseRandom[tank] || RPG_Perks_GetZombieType(tank) != ZombieType_Tank || RPG_Tanks_GetClientTank(tank) != tankIndex)
    {
        g_bReleaseRandom[tank] = false;

        int clients[MAXPLAYERS+1], num;

        for(int i=1;i <= MaxClients;i++)
        {
            if(!IsClientInGame(i))
                continue;        

            else if(!g_bEaten[i][tank])
                continue;

            clients[num++] = i;
        }

        int target = clients[GetRandomInt(0, num-1)];

        PlacePlayerOUTSIDETankBelly(target, tank);

        PrintToChatAll("%N was vomitted from the Tank!", target);

        float fOrigin[3];
        GetClientAbsOrigin(tank, fOrigin);

        for(int i=1;i <= MaxClients;i++)
        {
            if(!IsClientInGame(i))
                continue;

            else if(!IsPlayerAlive(i))
                continue;

            else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
                continue;

            float fSurvivorOrigin[3];
            GetClientAbsOrigin(i, fSurvivorOrigin);

            if (GetVectorDistance(fOrigin, fSurvivorOrigin) < g_fVomitRadius && !IsPlayerBoomerBiled(i))
            {
                L4D_CTerrorPlayer_OnVomitedUpon(i, tank);
            }
        }

        if(target == entity)
            return;
    }
    else
    {
        GetEntPropVector(tank, Prop_Data, "m_vecAbsOrigin", g_fLastOrigin[tank]);
    }
    
    g_iOldHealth[entity] -= RoundToCeil(float(g_iOldMaxHealth[entity]) * 0.01);


    if(g_iOldHealth[entity] <= 0)
    {
        // This clears g_iEatAttacker.
        ProcessClientInsideTank(entity);

        PrintToChatAll("%N was PROCESSED inside the Tank!!!", entity);

        return;
    }

    RPG_Perks_ApplyEntityTimedAttribute(entity, "Eaten Alive", 1.0, COLLISION_SET, ATTRIBUTE_NEGATIVE, TRANSFER_NORMAL);
}
stock int FindRandomSurvivorWithoutIncap(int client, float fMaxDistance)
{
    float fOrigin[3];
    GetClientAbsOrigin(client, fOrigin);

    int   winner    = -1;
    float winnerDistance = fMaxDistance;

    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        // Technically unused because the tank can never be survivor but still...
        else if(client == i)
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(L4D_IsPlayerIncapacitated(i))
            continue;

        float fSurvivorOrigin[3];
        GetClientAbsOrigin(i, fSurvivorOrigin);

        if (GetVectorDistance(fOrigin, fSurvivorOrigin) < winnerDistance)
        {
            winner    = i;
            winnerDistance = GetVectorDistance(fOrigin, fSurvivorOrigin);
        }
    }

    return winner;
}

public void RegisterTank()
{
    tankIndex = RPG_Tanks_RegisterTank(2, 2, "Glutton", "A tank that learned the size difference between survivors and Tanks.\nThe Tank's name shows percent of HP the closest eaten survivor to death is.", "Eats survivors, shove the tank to release them (Right Click)",
    3000000, 180, 0.2, 2500, 4000, DAMAGE_IMMUNITY_BURN|DAMAGE_IMMUNITY_MELEE|DAMAGE_IMMUNITY_EXPLOSIVES);

    char sDesc[256];
    FormatEx(sDesc, sizeof(sDesc), "Eats the closest 2 standing survivors in 256 units distance\nIf no survivor is found, the Tank applies NIGHTMARE on all survivors for %.0f seconds.", g_fNightmareDuration);
    eatSurvivorIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Eat Survivor", sDesc, 40, 60);

    RPG_Tanks_RegisterPassiveAbility(tankIndex, "Process Survivor", "Survivors being eaten take 1{PERCENT} damage each second, and become PROCESSED when incapped.\nTank heals 400k HP when a survivor is PROCESSED.");

    char TempFormat[512];
    FormatEx(TempFormat, sizeof(TempFormat), "Shoving the tank has a %i{PERCENT} chance to force\nthe Tank to vomit the survivor, biling all survivors in punching range.", g_iReleaseChance);
    RPG_Tanks_RegisterPassiveAbility(tankIndex, "Weak Spot", TempFormat);

    RPG_Tanks_RegisterPassiveAbility(tankIndex, "Sticky Bile", "No matter the source, Survivors gain STUN for 10 seconds when Biled.");
}

stock int CountEatenSurvivors(int tank)
{
    int count = 0;

    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;        

        else if(!g_bEaten[i][tank])
            continue;

        count++;
    }

    return count;
}

stock void PlacePlayerINSIDETankBelly(int victim, int attacker, int replacer = 0)
{
    if(replacer == 0)
    {
        g_iOldHealth[victim] = GetEntityHealth(victim);
        g_iOldMaxHealth[victim] = GetEntityMaxHealth(victim);
    }
    else
    {
        g_iOldHealth[victim] = g_iOldHealth[replacer];
        g_iOldMaxHealth[victim] = g_iOldMaxHealth[replacer];
    }

    L4D_State_Transition(victim, STATE_OBSERVER_MODE);

    g_bEaten[victim][attacker] = true;
    g_iEatAttacker[victim] = attacker;

    RPG_Perks_ApplyEntityTimedAttribute(victim, "Eaten Alive", 0.0, COLLISION_SET, ATTRIBUTE_NEGATIVE, TRANSFER_NORMAL);
}

stock void PlacePlayerOUTSIDETankBelly(int victim, int attacker, bool bDontTeleport = false)
{
    g_bEaten[victim][attacker] = false;
    g_iEatAttacker[victim] = 0;

    L4D_State_Transition(victim, STATE_WAITING_FOR_RESCUE);

    L4D_RespawnPlayer(victim);

    RPG_Perks_RecalculateMaxHP(victim);

    int hp = RoundToFloor(float(g_iOldHealth[victim]) / float(g_iOldMaxHealth[victim]) * float(RPG_Perks_GetClientMaxHealth(victim)));
    SetEntityHealth(victim, hp);

    if(!bDontTeleport)
    {
        float fOrigin[3];
        GetEntPropVector(attacker, Prop_Data, "m_vecAbsOrigin", fOrigin);

        TeleportEntity(victim, fOrigin, NULL_VECTOR, NULL_VECTOR);
    }

    RPG_Perks_ApplyEntityTimedAttribute(victim, "Eaten Alive", 0.0, COLLISION_SET, ATTRIBUTE_NEGATIVE, TRANSFER_NORMAL);
}

stock void ReplacePlayersFromTankBelly(int oldClient, int newClient)
{
    if(g_iEatAttacker[oldClient] == 0)
        return;

    int tank = g_iEatAttacker[oldClient];

    PlacePlayerOUTSIDETankBelly(oldClient, tank, true);

    PlacePlayerINSIDETankBelly(newClient, tank, oldClient);
}

stock void ProcessClientInsideTank(int client)
{
    int tank = g_iEatAttacker[client];

    PlacePlayerOUTSIDETankBelly(client, tank, true);

    char TempFormat[64];
    FormatEx(TempFormat, sizeof(TempFormat), "Glutton Instant Kill #%i", GetClientUserId(tank));

    RPG_Perks_ApplyEntityTimedAttribute(client, TempFormat, 0.1, COLLISION_SET, ATTRIBUTE_NEUTRAL);

    GunXP_RegenerateTankHealth(tank, 400000);
}

stock bool IsPlayerBoomerBiled(int iClient)
{
    return (GetGameTime() <= GetEntPropFloat(iClient, Prop_Send, "m_itTimer", 1));
}