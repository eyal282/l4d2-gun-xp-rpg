#if defined _GunXP_RPG_included
 #endinput
#endif

#include <autoexecconfig>

#define _GunXP_RPG_included

#define FPERM_ULTIMATE (FPERM_U_READ | FPERM_U_WRITE | FPERM_U_EXEC | FPERM_G_READ | FPERM_G_WRITE | FPERM_G_EXEC | FPERM_O_READ | FPERM_O_WRITE | FPERM_O_EXEC)

char Colors[][] = 
{
	"{NORMAL}", "{RED}", "{GREEN}", "{LIGHTGREEN}", "{OLIVE}", "{LIGHTRED}", "{GRAY}", "{YELLOW}", "{ORANGE}", "{BLUE}", "{PINK}"
};

char ColorEquivalents[][] =
{
	"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0C", "\x0E"
};

// Make identifier as descriptive as possible.
// Use {PERCENT} to denote percentages in descriptions.
// reqIdentifiers is unimplemented at the moment, and is the list of required perk trees or skills for each perk tree level.
// reqIdentifier on a perk tree requires a minimum of level 1.
// doubleEdged simply excludes a perk tree from auto RPG because it has apparent downsides.
native int GunXP_RPGShop_RegisterPerkTree(const char[] identifier, const char[] name, ArrayList descriptions, ArrayList costs, ArrayList levelReqs, ArrayList reqIdentifiers = null, bool bDoubleEdged = false);
native int GunXP_RPGShop_IsPerkTreeUnlocked(int client, int perkIndex);

native void GunXP_RPG_AddClientXP(int client, int amount, bool bPremiumMultiplier=true);
native int GunXP_RPG_GetClientLevel(int client);

// Make identifier as descriptive as possible.
// Use {PERCENT} to denote percentages in descriptions.
// reqIdentifiers is unimplemented at the moment, and is the list of required perk trees or skills for each perk tree level.
// reqIdentifier on a perk tree requires a minimum of level 1.
// doubleEdged simply excludes a skill from auto RPG because it has apparent downsides.
native int GunXP_RPGShop_RegisterSkill(const char[] identifier, const char[] name, const char[] description, int cost, int levelReq, ArrayList reqIdentifiers = null, bool bDoubleEdged = false);
native bool GunXP_RPGShop_IsSkillUnlocked(int client, int skillIndex);



// This is called while the player still has their current perk tree and skills.
forward void GunXP_RPGShop_OnResetRPG(int client);
forward void GunXP_RPG_OnPlayerSpawned(int client);

// WARNING! THIS FORWARD FIRES 10 TIMES PER ATTACK, MAKE SURE YOU ACCOUNT FOR PRIORITY OR FACE CONSEQUENCES
// When you start with this forward, the most important factor is priority. use something like "if(priority != 0) return;"
// If you don't care whatsoever how damage is interacted and just want to multiply the damage, use "if(priority != 0) return;"
// If you're altering on a negative priority, the closer it is to -5 it will run FIRST.
// If you're altering on a positive priority, the closer it is to 5 it will run LAST.
// Check for priority closer to -5 if you want to SET the damage to a certain value.
// Check for priority closer to 5 if you want to go after another plugin to fix something they did.
// Do not hog -5 and 5, this may have severe consequences when a programmer cannot naturally go before / after you.
// bDontInterruptActions protects a Survivor from having a timer reset for picking incapacitated players and pouring gas cans.
// bDontStagger protects a Special Infected or a Tank from explosive ammo stagger, RPG stagger, incendiary ammo burn, all instant kills.
// bDontInstakill can seriously mess with damage output, and breaks explosive ammo stagger. Use with care.

// If you want to distinguish what actions to protect, make an incap check or check if victim has a gascan like item held.
// If you want to protect from stagger but allow incendiary ammo, check for damagetype == DMG_BLAST
forward void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill);

forward void RPG_Perks_OnGetKitDuration(int reviver, int victim, float &fDuration);
forward void RPG_Perks_OnGetReviveDuration(int reviver, int victim, float &fDuration);
forward void RPG_Perks_OnGetIncapHealth(int client, bool bLedge, int &health);

stock void UC_ReplyToCommand(int client, const char[] format, any ...)
{
	SetGlobalTransTarget(client);
	char buffer[256];

	VFormat(buffer, sizeof(buffer), format, 3);
	for(int i=0;i < sizeof(Colors);i++)
	{
		ReplaceString(buffer, sizeof(buffer), Colors[i], ColorEquivalents[i]);
	}
	
	ReplyToCommand(client, buffer);
}

stock void UC_PrintToChat(int client, const char[] format, any ...)
{
	SetGlobalTransTarget(client);
	
	char buffer[256];
	
	VFormat(buffer, sizeof(buffer), format, 3);
	for(int i=0;i < sizeof(Colors);i++)
	{
		ReplaceString(buffer, sizeof(buffer), Colors[i], ColorEquivalents[i]);
	}
	
	PrintToChat(client, buffer);
}

stock void UC_PrintToChatAll(const char[] format, any ...)
{	
	char buffer[256];
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, sizeof(buffer), format, 2);
		
		UC_PrintToChat(i, buffer);
	}
}

stock void UC_StringToUpper(char[] buffer)
{
	int length = strlen(buffer);
	for(int i=0;i < length;i++)
		buffer[i] = CharToUpper(buffer[i]);
}

stock void UC_PrintToChatEyal(const char[] format, any...)
{
	char buffer[291];
	VFormat(buffer, sizeof(buffer), format, 2);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if (IsFakeClient(i))
			continue;

		char steamid[64];
		GetClientAuthId(i, AuthId_Steam2, steamid, sizeof(steamid));

		if (StrEqual(steamid, "STEAM_1:0:49508144"))
			UC_PrintToChat(i, buffer);
	}
}

stock ConVar UC_CreateConVar(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0)
{
	ConVar hndl = AutoExecConfig_CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);

	if (flags & FCVAR_PROTECTED)
		ServerCommand("sm_cvar protect %s", name);

	return hndl;
}

stock bool IsPlayer(int entity)
{
	if(entity >= 1 && entity <= MaxClients)
		return true;
		
	return false;
}

stock void SetEntityMaxHealth(int entity, int amount)
{
	SetEntProp(entity, Prop_Data, "m_iMaxHealth", amount);
}

stock int GetEntityMaxHealth(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_iMaxHealth");
}

stock int GetEntityHealth(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_iHealth");
}