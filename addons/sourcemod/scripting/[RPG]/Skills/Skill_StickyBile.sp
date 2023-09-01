
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
	name        = "Sticky Bile Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that makes bile stun targets for x seconds",
	version     = PLUGIN_VERSION,
	url         = ""
};

ConVar g_hDamagePriority;

int bileIndex;

float g_fStunTimeCommons = 30.0;
float g_fStunTimeSpecials = 15.0;
float g_fStunTimeTanks = 5.0;

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "GunXP_SkillShop"))
	{
		RegisterSkill();
	}
}
/*
public void OnEntityDestroyed(int entity)
{
    if(!IsValidEdict(entity))
        return;

    char sClassname[64];
    GetEdictClassname(entity, sClassname, sizeof(sClassname));
    
    if(StrEqual(sClassname, "vomitjar_projectile"))
    {
		int count = GetEntityCount();
		for (int a = MaxClients+1;a < count;a++)
		{
			if(!IsValidEdict(a))
				continue;

			char sClassname[64];
			GetEdictClassname(a, sClassname, sizeof(sClassname));

			if(StrEqual(sClassname, "infected"))
			{
				Address address = view_as<Address>(LoadFromAddress(GetEntityAddress(entity) + view_as<Address>(7544), NumberType_Int32));

                PrintToChatEyal("%.2f", CTimer_GetElapsedTime(GetEntData(entity, 1886)));
			}
		}
    }
}
*/
public void OnConfigsExecuted()
{
    RegisterSkill();

}
public void OnPluginStart()
{
    HookEvent("player_now_it", Event_PlayerNowIt);

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public Action Event_PlayerNowIt(Handle hEvent, const char[] Name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
    
	if(attacker == 0 || victim == 0)
		return;

    else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, bileIndex))
		return;

    
    float fDuration = g_fStunTimeSpecials;

    if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
        fDuration = g_fStunTimeTanks;

    RPG_Perks_ApplyEntityTimedAttribute(victim, "Stun", fDuration, COLLISION_SET_IF_HIGHER);
}
public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "Bile jar becomes extremely sticky\nStuns Common Infected for %.0f seconds\nStuns Special Infected for %.0f seconds\nStuns Tanks for %.0f seconds.\nNote: At the moment commons won't be stunned due to a bug", g_fStunTimeCommons, g_fStunTimeSpecials, g_fStunTimeTanks);
   	bileIndex = GunXP_RPGShop_RegisterSkill("Sticky Bile", "Sticky Bile", sDescription,
	500000, 0);
}


