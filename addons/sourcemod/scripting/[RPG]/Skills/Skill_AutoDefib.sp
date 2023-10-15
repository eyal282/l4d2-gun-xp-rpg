
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
	name        = "Auto Defib Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that automatically activates your defib when you die.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int skillIndex;

int g_iDeathDefib[MAXPLAYERS+1] = { INVALID_ENT_REFERENCE, ... };
float g_fDeathOrigin[MAXPLAYERS+1][3];
int g_iLastButtons[MAXPLAYERS+1];
float g_fNextExpireJump[MAXPLAYERS+1];
int g_iJumpCount[MAXPLAYERS+1];

bool g_bSpam[MAXPLAYERS+1];

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


public void OnMapStart()
{
	for(int i=0;i < sizeof(g_fNextExpireJump);i++)
	{
		g_fNextExpireJump[i] = 0.0;

		g_iJumpCount[i] = 0;
	}

	CreateTimer(2.5, Timer_CheckDeathDefib, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}


public Action Timer_CheckDeathDefib(Handle hTimer)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		FindClientDeathDefib(i);
	}

	return Plugin_Continue;
}

public void OnPluginStart()
{
	RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	int lastButtons = g_iLastButtons[client];

	g_iLastButtons[client] = buttons;

	if(g_bSpam[client] || IsPlayerAlive(client) || RPG_Perks_IsEntityTimedAttribute(client, "Auto Defib"))
		return Plugin_Continue;

	if(buttons & IN_SPEED && !(lastButtons & IN_SPEED) && g_fNextExpireJump[client] > GetGameTime())
	{
	
		g_fNextExpireJump[client] = GetGameTime() + 1.5;
		g_iJumpCount[client]++;


		if(g_iJumpCount[client] >= 3 && GunXP_RPGShop_IsSkillUnlocked(client, skillIndex))
		{
			int entity = EntRefToEntIndex(g_iDeathDefib[client]);

			if(entity == INVALID_ENT_REFERENCE)
			{
				PrintToChat(client, "You didn't die with a defib equipped.");

				g_iJumpCount[client] = 0;

				return Plugin_Continue;
			}

			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			
			if(owner != -1)
			{
				PrintToChat(client, "Someone took your defib since you died.");

				g_iJumpCount[client] = 0;

				return Plugin_Continue;
			}
			
			PrintToChat(client, "Activated Auto Defib. Respawning in 10 seconds...");

			RPG_Perks_ApplyEntityTimedAttribute(client, "Auto Defib", 10.0, COLLISION_SET, ATTRIBUTE_POSITIVE);

			g_iJumpCount[client] = 0;
		}
		
		return Plugin_Continue;
	}

	if(g_fNextExpireJump[client] <= GetGameTime())
	{
		g_iJumpCount[client] = 0;
		g_fNextExpireJump[client] = GetGameTime() + 1.5;

		if(buttons & IN_SPEED)
		{
			g_iJumpCount[client]++;
		}
	}

	return Plugin_Continue;
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority != 10)
		return;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_NotInfected)
		return;	
		
	FindClientDeathDefib(victim);
}
public void RPG_Perks_OnShouldInstantKill(int priority, int victim, int attacker, int inflictor, int damagetype, bool &bImmune)
{
	if(priority != 10)
		return;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_NotInfected)
		return;

	FindClientDeathDefib(victim);
}

public void FindClientDeathDefib(int client)
{
	int entity = GetPlayerWeaponSlot(client, L4D_WEAPON_SLOT_MEDKIT);

	if(entity == -1)
	{
		g_iDeathDefib[client] = INVALID_ENT_REFERENCE;

		return;
	}

	char sClassname[64];
	GetEdictClassname(entity, sClassname, sizeof(sClassname));

	if(!StrEqual(sClassname, "weapon_defibrillator"))
	{
		g_iDeathDefib[client] = INVALID_ENT_REFERENCE;

		return;
	}

	g_iDeathDefib[client] = EntIndexToEntRef(entity);
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", g_fDeathOrigin[client]);
}

public void RPG_Perks_OnTimedAttributeExpired(int attributeEntity, char attributeName[64])
{
	if(!StrEqual(attributeName, "Auto Defib"))
		return;
	

	int client = attributeEntity;

	if(IsPlayerAlive(client))
		return;

	int entity = EntRefToEntIndex(g_iDeathDefib[client]);

	if(entity == INVALID_ENT_REFERENCE)
	{
		PrintToChat(client, "You didn't die with a defib equipped.");

		return;
	}

	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if(owner != -1)
	{
		PrintToChat(client, "Someone took your defib since you died.");

		return;
	}

	AcceptEntityInput(entity, "Kill");

	SetEntityMaxHealth(client, 100);

	L4D2_VScriptWrapper_ReviveByDefib(client);

	TeleportEntity(client, g_fDeathOrigin[client], NULL_VECTOR, NULL_VECTOR);

	RPG_Perks_RecalculateMaxHP(client);

	g_iDeathDefib[client] = INVALID_ENT_REFERENCE;
}

public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
	if(!StrEqual(attributeName, "Auto Defib"))
		return;



	// Not possible to transfer to common or witch...
	g_iDeathDefib[newClient] = g_iDeathDefib[oldClient];
	g_fDeathOrigin[newClient] = g_fDeathOrigin[oldClient];

	if(oldClient == newClient)
		return;
		
	g_iDeathDefib[oldClient] = INVALID_ENT_REFERENCE;
	g_fDeathOrigin[oldClient] = NULL_VECTOR;
}

public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "Triple click SHIFT to activate\nYour Defib will automatically activate to revive you when you die.\nTakes 10 seconds to activate, and requires your defib to not be taken by another player.");

	skillIndex = GunXP_RPGShop_RegisterSkill("Auto Defib", "Auto Defib", sDescription,
	2000000, 0);
}

