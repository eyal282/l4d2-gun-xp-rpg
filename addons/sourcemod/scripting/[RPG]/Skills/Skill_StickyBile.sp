
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define ACID_TIME			7.2

#define MAX_LIGHTS 10

public Plugin myinfo =
{
	name        = "Sticky Bile Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that makes bile stun targets for x seconds",
	version     = PLUGIN_VERSION,
	url         = ""
};

int bileIndex;

float g_fStunTimeCommons = 30.0;
float g_fStunTimeSpecials = 15.0;
float g_fStunTimeTanks = 5.0;

int g_iEntities[MAX_LIGHTS][2], g_iTick[MAX_LIGHTS];
bool g_bMapStarted, g_bFrameProcessing;
float g_fFaderTick[MAX_LIGHTS], g_fFaderStart[MAX_LIGHTS], g_fFaderEnd[MAX_LIGHTS];

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
	HookEvent("player_now_it", Event_PlayerNowIt);

	RegisterSkill();
}

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public void OnEntityDestroyed(int entity)
{
	if(!IsValidEntityIndex(entity))
		return;

	char sClassname[64];
	GetEdictClassname(entity, sClassname, sizeof(sClassname));
	
	if(!StrEqual(sClassname, "vomitjar_projectile"))
		return;
	
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");

	if(owner == -1)
		return;

	else if(!GunXP_RPGShop_IsSkillUnlocked(owner, bileIndex))
		return;

	float fOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);

	fOrigin[2] += 128.0;

	int acid = L4D2_SpitterPrj(owner, fOrigin, view_as<float>({0.0, 0.0, 0.0}));

	L4D_DetonateProjectile(acid);

	RPG_Perks_ApplyEntityTimedAttribute(owner, "Sticky Bile Pool Owner", 15.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(g_bMapStarted)
	{
		if(StrEqual(classname, "insect_swarm"))
		{
			CreateTimer(0.1, TimerCreate, EntIndexToEntRef(entity));
		}
	}
}

public Action TimerCreate(Handle timer, any target)
{
	if( (target = EntRefToEntIndex(target)) != INVALID_ENT_REFERENCE )
	{
		int index = -1;

		for( int i = 0; i < MAX_LIGHTS; i++ )
		{
			if( IsValidEntRef(g_iEntities[i][0]) == false )
			{
				index = i;
				break;
			}
		}

		if( index == -1 )
			return Plugin_Continue;

		char sTemp[64];
		int entity = CreateEntityByName("light_dynamic");
		if( entity == -1)
		{
			LogError("Failed to create 'light_dynamic'");
			return Plugin_Continue;
		}

		g_iEntities[index][0] = EntIndexToEntRef(entity);
		g_iEntities[index][1] = EntIndexToEntRef(target);

		DispatchKeyValue(entity, "_light", "200 80 200 255");
		DispatchKeyValue(entity, "brightness", "3");
		DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
		DispatchKeyValueFloat(entity, "distance", 5.0);
		DispatchKeyValue(entity, "style", "6");
		DispatchSpawn(entity);

		float vPos[3], vAng[3];
		GetEntPropVector(target, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(target, Prop_Data, "m_angRotation", vAng);
		vPos[2] += 40.0;
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");

		float flTickInterval = GetTickInterval();
		int iTickRate = RoundFloat(1 / flTickInterval);

		// Fade
		if( !g_bFrameProcessing )
		{
			g_bFrameProcessing = true;
			RequestFrame(OnFrameFade);
		}

		g_iTick[index] = 7;
		g_fFaderEnd[index] = GetGameTime() + ACID_TIME - (flTickInterval * iTickRate);
		g_fFaderStart[index] = GetGameTime() + flTickInterval * iTickRate + 2.0;
		g_fFaderTick[index] = GetGameTime() - 1.0;

		Format(sTemp, sizeof(sTemp), "OnUser3 !self:Kill::%f:-1", ACID_TIME);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser3");
	}

	return Plugin_Continue;
}

void OnFrameFade()
{
	float fDisplayDist = 1024.0;

	g_bFrameProcessing = false;

	float fDist;
	float fTime = GetGameTime();
	float flTickInterval = GetTickInterval();
	int iTickRate = RoundFloat(1 / flTickInterval);

	// Loop through valid ents
	for( int i = 0; i < MAX_LIGHTS; i++ )
	{
		if( IsValidEntRef(g_iEntities[i][0]) )
		{
			g_bFrameProcessing = true;

			// Ready for fade on this tick
			if( fTime > g_fFaderTick[i] )
			{
				// Fade in
				if( fTime < g_fFaderStart[i] )
				{
					fDist = (fDisplayDist / iTickRate) * g_iTick[i];
					if( fDist < fDisplayDist )
					{
						SetVariantFloat(fDist);
						AcceptEntityInput(g_iEntities[i][0], "Distance");
					}

					g_iTick[i]++;
					g_fFaderTick[i] = fTime + flTickInterval;
				}
				// Fade out
				else if( fTime > g_fFaderEnd[i] )
				{
					fDist = (fDisplayDist / iTickRate) * (iTickRate - g_iTick[i]);
					if( fDist < fDisplayDist )
					{
						SetVariantFloat(fDist);
						AcceptEntityInput(g_iEntities[i][0], "Distance");
					}

					g_iTick[i]++;
					g_fFaderTick[i] = fTime + flTickInterval;
				}
				else
				{
					g_iTick[i] = 0;
				}
			}
		}
	}

	if( g_bFrameProcessing )
	{
		RequestFrame(OnFrameFade);
	}
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}
public Action L4D2_CInsectSwarm_CanHarm(int acid, int spitter, int entity)
{
	if(!IsPlayer(spitter))
		return Plugin_Continue;

	else if(RPG_Perks_IsEntityTimedAttribute(spitter, "Sticky Bile Pool Owner"))
	{
		if(!RPG_Perks_IsEntityTimedAttribute(entity, "Sticky Bile Cooldown"))
		{
			switch(RPG_Perks_GetZombieType(entity))
			{
				case ZombieType_NotInfected, ZombieType_Invalid:
				{

				}	
				case ZombieType_CommonInfected, ZombieType_Witch:
				{
					L4D2_Infected_OnHitByVomitJar(entity, spitter);
				}
				default:
				{
					L4D2_CTerrorPlayer_OnHitByVomitJar(entity, spitter);
				}
			}
		}
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Event_PlayerNowIt(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == 0 || victim == 0)
		return Plugin_Continue;

	if(RPG_Perks_GetZombieType(attacker) != ZombieType_NotInfected)
		return Plugin_Continue;

	else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, bileIndex))
		return Plugin_Continue;

	
	float fDuration = g_fStunTimeSpecials;

	if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
		fDuration = g_fStunTimeTanks;

	RPG_Perks_ApplyEntityTimedAttribute(victim, "Stun", fDuration, COLLISION_SET_IF_HIGHER, ATTRIBUTE_NEGATIVE);
	RPG_Perks_ApplyEntityTimedAttribute(victim, "Sticky Bile Cooldown", ACID_TIME + 1.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
	
	return Plugin_Continue;
}

public void L4D2_Infected_HitByVomitJar_Post(int victim, int attacker)
{
	if(RPG_Perks_GetZombieType(attacker) != ZombieType_NotInfected)
		return;

	else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, bileIndex))
		return;

	RPG_Perks_ApplyEntityTimedAttribute(victim, "Stun", g_fStunTimeCommons, COLLISION_SET_IF_HIGHER, ATTRIBUTE_NEGATIVE);
	RPG_Perks_ApplyEntityTimedAttribute(victim, "Sticky Bile Cooldown", ACID_TIME + 1.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
	
}
public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "Bile jar becomes extremely sticky\nStuns Common/Special/Tank for %.0f/%.0f/%.0f sec\nBile sticks to the ground, allowing to bile enemies that go through it.", g_fStunTimeCommons, g_fStunTimeSpecials, g_fStunTimeTanks);
	bileIndex = GunXP_RPGShop_RegisterSkill("Sticky Bile", "Sticky Bile", sDescription,
	500000, 0);
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}