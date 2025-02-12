
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
	name        = "Ultimate Samurai Skill --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Skill that makes melee swing incredibly fast.",
	version     = PLUGIN_VERSION,
	url         = ""
};

ConVar g_hDamagePriority;

int samuraiIndex;
int blitzIndex;

float g_fSwingSpeedPerLevels = 0.5;
float g_fSwingMaxSpeed = 5.0;
int g_iSwingSpeedLevels = 10;
float g_fMeleeDamagePerLevels = 0.1;
int g_iMeleeDamageLevels = 2;

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
	AutoExecConfig_SetFile("GunXP-UltimateSamuraiSkill.cfg");

	g_hDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgshop_ultimate_samurai_damage_priority", "0", "Do not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin sets the damage, negating any modifier another plugin made, so it must go first");

	AutoExecConfig_ExecuteFile();

	AutoExecConfig_CleanFile();

	RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

float g_fLastPrimaryAttack[MAXPLAYERS+1];

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse)
{
	if(!(buttons & IN_RELOAD))
		return Plugin_Continue;

	else if(!(buttons & IN_ATTACK))
		return Plugin_Continue;


	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	int pinner = L4D_GetPinnedInfected(client);

	if(pinner != 0)
		return Plugin_Continue;

	else if(L4D_IsPlayerStaggering(client))
		return Plugin_Continue;

	else if(IsClientAffectedByFling(client))
		return Plugin_Continue;

	else if(!HasMeleeEquipped(client, weapon))
		return Plugin_Continue;

	
	float fLastPrimaryAttack = g_fLastPrimaryAttack[client];

	g_fLastPrimaryAttack[client] = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");

	// Holding M1 is a bit buggy so both checks needed.
	if(GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") > GetGameTime() && GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") - fLastPrimaryAttack >= 0.01)
		return Plugin_Continue;

	else if(!GunXP_RPGShop_IsSkillUnlocked(client, blitzIndex))
		return Plugin_Continue;

	else if(RPG_Perks_IsEntityTimedAttribute(client, "Blitz Cooldown"))
		return Plugin_Continue;

	int target = GetClosestZombieToAim(client);

	if(target == 0)
		return Plugin_Continue;

	RPG_Perks_ApplyEntityTimedAttribute(client, "Blitz Cooldown", 0.2, COLLISION_SET, ATTRIBUTE_NEUTRAL);

	BlitzTeleport(client, target);

	return Plugin_Continue;
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority == 10)
	{
		if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
			return;

		else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
			return;
	
		else if(L4D2_GetWeaponId(inflictor) != L4D2WeaponId_Melee)
			return;

		else if(damagetype & DMG_BURN)
			return;
	
		else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, samuraiIndex))
			return;

		else if(damage == 0.0 || bImmune)
		{
			if(!RPG_Tanks_IsDamageImmuneTo(victim, DAMAGE_IMMUNITY_BURN))
			{
				RPG_Perks_IgniteWithOwnership(victim, attacker);
			}

			// Warning, infinite loop potential. This is negated by	else if(damagetype & DMG_BURN)
			RPG_Perks_TakeDamage(victim, attacker, inflictor, 0.0, DMG_BURN);
			return;
		}

		if(!RPG_Tanks_IsDamageImmuneTo(victim, DAMAGE_IMMUNITY_BURN))
		{
			RPG_Perks_IgniteWithOwnership(victim, attacker);
		}
	}
	if(priority != g_hDamagePriority.IntValue)
		return;

	else if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
		return;

	else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
		return;
		
	else if(L4D2_GetWeaponId(inflictor) != L4D2WeaponId_Melee)
		return;
	
	else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, samuraiIndex))
		return;

	if(damagetype & DMG_BURN)
		damage -= damage * 0.95;

	damage += damage * (1.0 + (g_fMeleeDamagePerLevels * float(RoundToFloor(float(GunXP_RPG_GetClientLevel(attacker)) / float(g_iMeleeDamageLevels)))));
}

public void WH_OnDeployModifier(int client, int weapon, int weapontype, float &speedmodifier)
{
	if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_Melee)
		return;

	else if(!GunXP_RPGShop_IsSkillUnlocked(client, samuraiIndex))
		return;

	speedmodifier = 10.0;
}

public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
	if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_Melee)
		return;
	
	else if(!GunXP_RPGShop_IsSkillUnlocked(client, samuraiIndex))
		return;


	if(g_fSwingSpeedPerLevels * float(RoundToFloor(float(GunXP_RPG_GetClientLevel(client)) / float(g_iSwingSpeedLevels))) >= g_fSwingMaxSpeed)
	{
		speedmodifier += g_fSwingMaxSpeed;
	}
	else
	{
		speedmodifier += g_fSwingSpeedPerLevels * float(RoundToFloor(float(GunXP_RPG_GetClientLevel(client)) / float(g_iSwingSpeedLevels)));
	}
}

public void RegisterSkill()
{
	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "Melee swings gain +%i{PERCENT} speed per %i levels (Max %i{PERCENT})\nDeploy melee instantly.\nMelee sets targets on fire.\n+%i{PERCENT} melee damage per %i levels.\nIf a Tank is immune to Melee but not fire, it will take 5{PERCENT} Fire damage.", RoundFloat(g_fSwingSpeedPerLevels * 100.0), g_iSwingSpeedLevels, RoundFloat(g_fSwingMaxSpeed * 100.0), RoundFloat(g_fMeleeDamagePerLevels * 100.0), g_iMeleeDamageLevels);
	samuraiIndex = GunXP_RPGShop_RegisterSkill("Ultimate Samurai", "Ultimate Samurai", sDescription,
	80000, 200000);

	blitzIndex = GunXP_RPGShop_RegisterSkill("TeleportToZombiesWithMelee", "Blitz", "Hold R while attacking with Melee to teleport to the closest zombie to your aim.\n0.2 sec cooldown to avoid mistakes.",
	3400, 3400);
}


stock bool HasMeleeEquipped(int client, int weapon = -1)
{
	if(weapon == -1)
	{
		weapon = L4D_GetPlayerCurrentWeapon(client);
	}

	if(GetPlayerWeaponSlot(client, L4D_WEAPON_SLOT_SECONDARY) != weapon)
		return false;

	char sClassname[64];
	GetEdictClassname(weapon, sClassname, sizeof(sClassname));

	if(StrEqual(sClassname, "weapon_melee"))
		return true;

	return false;
}

// exclusions exists to calculate aimbot levels as little as possible.
stock int GetClosestZombieToAim(int client, ArrayList exclusions = null)
{
	if(exclusions == null)
		exclusions = new ArrayList(1);

	int winner = 0;
	float winnerProduct = 1.0;

	float fOrigin[3], fAngles[3], fFwd[3];

	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, fAngles);

	GetAngleVectors(fAngles, fFwd, NULL_VECTOR, NULL_VECTOR);

	int siRealm[MAXPLAYERS+1], numSIRealm;
	int ciRealm[MAXPLAYERS+1], numCIRealm;
	int witchRealm[MAXPLAYERS+1], numWitchRealm;

	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);

	if(RPG_Perks_IsEntityTimedAttribute(client, "Shadow Realm"))
	{
		RPG_Perks_GetZombiesInRealms(
			_, _, siRealm, numSIRealm,
			_, _, ciRealm, numCIRealm,
			_, _, witchRealm, numWitchRealm);
	}
	else
	{
		RPG_Perks_GetZombiesInRealms(
			siRealm, numSIRealm, _, _,
			ciRealm, numCIRealm, _, _,
			witchRealm, numWitchRealm, _, _);
	}

	for(int i=0;i < numSIRealm;i++)
	{
		int victim = siRealm[i];

		if(GetEntPropEnt(victim, Prop_Send, "m_hOwnerEntity") != -1)
			continue;

		else if(exclusions.FindValue(victim) != -1)
			continue;

		float fTargetOrigin[3];
		GetClientEyePosition(victim, fTargetOrigin);

		float fSubOrigin[3];

		SubtractVectors(fOrigin, fTargetOrigin, fSubOrigin);

		NormalizeVector(fSubOrigin, fSubOrigin);

		float fDotProduct = GetVectorDotProduct(fFwd, fSubOrigin);

		if(winnerProduct > fDotProduct)
		{	
			winnerProduct = fDotProduct;
			winner = victim;
		}
	}

	for(int i=0;i < numCIRealm;i++)
	{
		int victim = ciRealm[i];

		if(exclusions.FindValue(victim) != -1)
			continue;

		float fTargetOrigin[3];
		GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fTargetOrigin);

		float fSubOrigin[3];

		SubtractVectors(fOrigin, fTargetOrigin, fSubOrigin);

		NormalizeVector(fSubOrigin, fSubOrigin);

		float fDotProduct = GetVectorDotProduct(fFwd, fSubOrigin);

		if(winnerProduct > fDotProduct)
		{
			winnerProduct = fDotProduct;
			winner = victim;
		}
	}

	for(int i=0;i < numWitchRealm;i++)
	{
		int victim = witchRealm[i];

		if(exclusions.FindValue(victim) != -1)
			continue;

		float fTargetOrigin[3];
		GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fTargetOrigin);

		float fSubOrigin[3];

		SubtractVectors(fOrigin, fTargetOrigin, fSubOrigin);

		NormalizeVector(fSubOrigin, fSubOrigin);

		float fDotProduct = GetVectorDotProduct(fFwd, fSubOrigin);

		if(winnerProduct > fDotProduct)
		{
			winnerProduct = fDotProduct;
			winner = victim;
		}
	}

	if(GunXP_SetupAimbotStrike(client, winner, AimbotLevel_Two))
		return winner;

	exclusions.Push(winner);

	return GetClosestZombieToAim(client, exclusions);
}

stock void BlitzTeleport(int client, int target)
{
	if(TeleportAroundTarget(client, target))
	{
		LookAtEntity(client, target);
	}
}

stock bool TeleportAroundTarget(int client, int target, float distance = 0.0)
{
	float targetPos[3], anglePos[3];
	float startAngle = GetRandomFloat(0.0, 360.0);
	
	float targetMins[3], targetMaxs[3];
	GetEntPropVector(target, Prop_Send, "m_vecMins", targetMins);
	GetEntPropVector(target, Prop_Send, "m_vecMaxs", targetMaxs);
	
	float clientMins[3], clientMaxs[3];
	GetEntPropVector(client, Prop_Send, "m_vecMins", clientMins);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", clientMaxs);

	float evilAIConstant = 0.7205559;
	
	// Calculate diagonal radii and apply empirically determined ratio
	float targetRadius = SquareRoot(targetMaxs[0] * targetMaxs[0] + targetMaxs[1] * targetMaxs[1]);
	float clientRadius = SquareRoot(clientMaxs[0] * clientMaxs[0] + clientMaxs[1] * clientMaxs[1]);
	float radius = (targetRadius + clientRadius) * evilAIConstant + distance;
	
	// Safety net.
	radius += 0.5;

	GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", targetPos);
	
	for(float angle = startAngle; angle < startAngle + 360.0; angle += 22.5)
	{
		anglePos[0] = targetPos[0] + (radius * Cosine(DegToRad(angle)));
		anglePos[1] = targetPos[1] + (radius * Sine(DegToRad(angle)));
		anglePos[2] = targetPos[2];
		
		TR_TraceHullFilter(anglePos, anglePos, clientMins, clientMaxs, MASK_PLAYERSOLID, TraceFilter_IgnoreSelf, client);
		
		if(!TR_DidHit())
		{
			float fakePos[3], floorPos[3];
			fakePos = anglePos;
			fakePos[2] = -999999.0;
	
			TR_TraceHullFilter(anglePos, fakePos, clientMins, clientMaxs, MASK_PLAYERSOLID, TraceFilter_IgnorePlayers);

			if(TR_DidHit())
			{
				TR_GetEndPosition(floorPos);

				if(GetVectorDistance(anglePos, floorPos) <= 64.0)
				{
					float angles[3];
					MakeVectorFromPoints(anglePos, targetPos, angles);
					GetVectorAngles(angles, angles);
					angles[0] = 0.0;
					angles[2] = 0.0;

					TeleportEntity(client, anglePos, angles, NULL_VECTOR);
					return true;
				}
			}
		}
	}
	
	return false;
}

public bool TraceFilter_IgnoreSelf(int entity, int contentsMask, any data)
{
	if(entity == data)
		return false;

	return true;
}

public bool TraceFilter_IgnorePlayers(int entity, int contentsMask, any data)
{
	if(!IsPlayer(entity))
		return false;
		
	return true;
}


stock void LookAtEntity(int client, int entity)
{
    float fTargetPos[3], fClientPos[3], fFinalPos[3];
    
    GetClientEyePosition(client, fClientPos);
    
    // For non-client entities, use their origin instead of eye position
    switch(RPG_Perks_GetZombieType(entity))
	{
		case ZombieType_CommonInfected:
		{
		    GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fTargetPos);
			fTargetPos[2] += 50.0;			
		}

		// She tends to sit.
		case ZombieType_Witch:
		{
		    GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fTargetPos);
			fTargetPos[2] += 8.0;			
		}
		default:
		{
			GetClientEyePosition(entity, fTargetPos);
			fTargetPos[2] -= 16.0;
		}
	}

    // Calculate direction vector from client to target
    MakeVectorFromPoints(fClientPos, fTargetPos, fFinalPos);
    
    // Convert to angles
    GetVectorAngles(fFinalPos, fFinalPos);
    
    // Apply the new view angles
    TeleportEntity(client, NULL_VECTOR, fFinalPos, NULL_VECTOR);
}
stock void AddInFrontOf(float fVecOrigin[3], float fVecAngle[3], float fUnits, float fOutPut[3])
{
	float fVecView[3]; GetViewVector(fVecAngle, fVecView);
	
	fOutPut[0] = fVecView[0] * fUnits + fVecOrigin[0];
	fOutPut[1] = fVecView[1] * fUnits + fVecOrigin[1];
	fOutPut[2] = fVecView[2] * fUnits + fVecOrigin[2];
}

stock void GetViewVector(float fVecAngle[3], float fOutPut[3])
{
	fOutPut[0] = Cosine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[1] = Sine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[2] = -Sine(fVecAngle[0] / (180 / FLOAT_PI));
}

bool IsClientAffectedByFling(int client)
{
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);
	switch (model[29])
	{
		case 'b':    // nick
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 661, 667, 669, 671, 672, 627, 628, 629, 630, 620:
					return true;
			}
		}
		case 'd':    // rochelle
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 668, 674, 676, 678, 679, 635, 636, 637, 638, 629:
					return true;
			}
		}
		case 'c':    // coach
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 650, 656, 658, 660, 661, 627, 628, 629, 630, 621:
					return true;
			}
		}
		case 'h':    // ellis
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 665, 671, 673, 675, 676, 632, 633, 634, 635, 625:
					return true;
			}
		}
		case 'v':    // bill
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 753, 759, 761, 763, 764, 535, 536, 537, 538, 528:
					return true;
			}
		}
		case 'n':    // zoey
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 813, 819, 821, 823, 824, 544, 545, 546, 547, 537:
					return true;
			}
		}
		case 'e':    // francis
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 756, 762, 764, 766, 767, 538, 539, 540, 541, 531:
					return true;
			}
		}
		case 'a':    // louis
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 753, 759, 761, 763, 764, 535, 536, 537, 538, 528:
					return true;
			}
		}
	}
	return false;
}