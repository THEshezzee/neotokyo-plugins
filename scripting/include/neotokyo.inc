#if defined _neotokyo_included
  #endinput
#endif
#define _neotokyo_included

// Increment the:
//   MAJOR version when you make incompatible API changes
//   MINOR version when you add functionality in a backwards compatible manner
//   PATCH version is not used; when you make backwards compatible bug fixes,
//   that change should not increment the version numbering.
#define NEO_INC_V_MAJOR 1
#define NEO_INC_V_MINOR 3

// Starting with SM 1.11, errors in unused stock functions are no longer suppressed.
// This means we have to include any dependencies here, regardless of whether they're
// actually used, or otherwise user code including this .inc file will error on compile.
#if SOURCEMOD_V_MAJOR > 1 || (SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR >= 11)
#include <sdktools> // Required by RemovePlayerItem()
#endif

#define NEO_MAXPLAYERS	32

#define TEAM_NONE		0
#define TEAM_SPECTATOR	1
#define TEAM_JINRAI 	2
#define TEAM_NSF		3

/// The "m_iGameState" states of Neotokyo gamerules proxy
//
// The "Waiting for players..." state when Jinrai and/or NSF is empty
#define GAMESTATE_WAITING_FOR_PLAYERS 1
// Both teams have players, and round has not ended yet
#define GAMESTATE_ROUND_ACTIVE 2
// Round has concluded (win or tie), but the next round hasn't started yet
#define GAMESTATE_ROUND_OVER 3

#define AMMO_GRENADE	1
#define AMMO_SMOKE		2
#define AMMO_PRIMARY	4
#define AMMO_SECONDARY	5
#define AMMO_PZ			7
#define AMMO_SHOTGUN	11

#define VISION_NONE		0
#define VISION_NIGHT	2
#define VISION_THERMAL 	3
#define VISION_MOTION	4

#define CLASS_NONE		0
#define CLASS_RECON		1
#define CLASS_ASSAULT	2
#define CLASS_SUPPORT	3

// The RANK_... defines are the "m_iRank" entprops,
// except for RANK_INVALID, which is a custom magic value
// that can be used to indicate no rank is applicable,
// for example for weapon loadout access logic.
#define RANK_INVALID -1
#define RANK_RANKLESSDOG 0
#define RANK_PRIVATE 1
#define RANK_CORPORAL 2
#define RANK_SERGEANT 3
#define RANK_LIEUTENANT 4

#define STAR_UNASSIGNED 0
#define STAR_ALPHA 1
#define STAR_BRAVO 2
#define STAR_CHARLIE 3
#define STAR_DELTA 4
#define STAR_ECHO 5

#define IN_AIM			(1 << 23)
#define IN_LEANL		(1 << 24)
#define IN_LEANR		(1 << 25)
#define IN_SPRINT		(1 << 26)
#define IN_THERMOPTIC	(1 << 27)
#define IN_VISION		(1 << 28)
#define IN_TOSS			(1 << 29)

#define SLOT_NONE -1
#define SLOT_PRIMARY 0
#define SLOT_SECONDARY 1
#define SLOT_MELEE 2
#define SLOT_GRENADE 3

char weapons_primary[][] = {
	"weapon_ghost",
	"weapon_mpn",
	"weapon_srm",
	"weapon_srm_s",
	"weapon_jitte",
	"weapon_jittescoped",
	"weapon_zr68c",
	"weapon_zr68l",
	"weapon_zr68s",
	"weapon_supa7",
	"weapon_m41",
	"weapon_m41s",
	"weapon_mx",
	"weapon_mx_silenced",
	"weapon_aa13",
	"weapon_srs",
	"weapon_pz"
};

char weapons_secondary[][] = {
	"weapon_tachi",
	"weapon_milso",
	"weapon_kyla"
};

char weapons_grenade[][] = {
	"weapon_grenade",
	"weapon_smokegrenade",
	"weapon_remotedet"
};

stock int GetRankOfXP(int xp)
{
	if (xp < 0)
		return RANK_RANKLESSDOG;
	if (xp < 4)
		return RANK_PRIVATE;
	if (xp < 10)
		return RANK_CORPORAL;
	if (xp < 20)
		return RANK_SERGEANT;
	return RANK_LIEUTENANT;
}

stock void SetPlayerXP(int client, int xp)
{
	SetEntProp(client, Prop_Data, "m_iFrags", xp);
	SetPlayerRank(client, GetRankOfXP(xp));
}

stock int GetPlayerXP(int client)
{
	return GetClientFrags(client);
}

stock void UpdatePlayerRank(int client)
{
	SetPlayerRank(client, GetRankOfXP(GetPlayerXP(client)));
}

stock int GetPlayerRank(int client)
{
	return GetEntProp(client, Prop_Send, "m_iRank");
}

stock void SetPlayerRank(int client, int rank)
{
	SetEntProp(client, Prop_Send, "m_iRank", rank);
}

stock int GetPlayerDeaths(int client)
{
	return GetEntProp(client, Prop_Data, "m_iDeaths");
}

stock void SetPlayerDeaths(int client, int deaths)
{
	SetEntProp(client, Prop_Data, "m_iDeaths", deaths);
}

stock int GetPlayerStar(int client)
{
	return GetEntProp(client, Prop_Send, "m_iStar");
}

stock void SetPlayerStar(int client, int star)
{
	if(star < STAR_UNASSIGNED || star > STAR_ECHO)
		return;

	SetEntProp(client, Prop_Send, "m_iStar", star);
}

stock void SetPlayerClass(int client, int class)
{
	SetEntProp(client, Prop_Send, "m_iClassType", class);
}

stock int GetPlayerClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_iClassType");
}

stock int GetAmmoType(int weapon)
{
	return GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
}

stock int GetWeaponAmmo(int client, int type)
{
	static int m_iAmmo;

	if(!m_iAmmo && (m_iAmmo = FindSendPropInfo("CBasePlayer", "m_iAmmo")) == -1)
	{
		ThrowError("Failed to obtain offset: \"m_iAmmo\"!");
	}

	return GetEntData(client, m_iAmmo + (type * 4));
}

stock void SetWeaponAmmo(int client, int type, int ammo)
{
	static int m_iAmmo;

	if(!m_iAmmo && (m_iAmmo = FindSendPropInfo("CBasePlayer", "m_iAmmo")) == -1)
	{
		ThrowError("Failed to obtain offset: \"m_iAmmo\"!");
	}

	SetEntData(client, m_iAmmo + (type * 4), ammo);
}

stock int GetActiveWeapon(int client)
{
	return GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
}

stock int GetPlayerVision(int client)
{
	return GetEntProp(client, Prop_Send, "m_iVision");
}

stock void SetPlayerVision(int client, int vision)
{
	SetEntProp(client, Prop_Send, "m_iVision", vision);
}

stock int GetPlayerLean(int client)
{
	return GetEntProp(client, Prop_Send, "m_iLean");
}

stock void SetPlayerLean(int client, int lean)
{
	SetEntProp(client, Prop_Send, "m_iLean", lean);
}

stock float GetPlayerAUX(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_fSprintNRG");
}

stock void SetPlayerAUX(int client, float amount)
{
	SetEntPropFloat(client, Prop_Send, "m_fSprintNRG", amount);
}

stock float GetPlayerThermopticCharge(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_fThermopticNRG");
}

stock void SetPlayerThermopticCharge(int client, float amount)
{
	SetEntPropFloat(client, Prop_Send, "m_fThermopticNRG", amount);
}

stock bool IsCloaked(int client)
{
	int cloaked = GetEntProp(client, Prop_Send, "m_iThermoptic");

	if (cloaked > 0)
		return true;

	return false;
}

stock bool IsLeaning(int client)
{
	if (GetPlayerLean(client) > 0)
		return true;

	return false;
}

stock bool IsUsingVision(int client)
{
	if (GetPlayerVision(client) > 0)
		return true;

	return false;
}

stock bool IsValidClient(int client, bool ignoreClientInGameState = false)
{
	if (client < 1 || client > MaxClients)
		return false;

	if(!ignoreClientInGameState && !IsClientInGame(client))
		return false;

	return true;
}

stock void StripPlayerWeapons(int client, bool knife=false)
{
	static int hMyWeapons;

	if(!hMyWeapons && (hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons")) == -1)
	{
		ThrowError("Failed to obtain offset: \"m_hMyWeapons\"!");
	}

	char classname[13];
	for(int slot = 0; slot <= 5; slot++)
	{
		int weapon = GetEntDataEnt2(client, hMyWeapons + (slot * 4));

		if(!IsValidEntity(weapon))
			continue;

		if(knife)
		{
			if(!GetEdictClassname(weapon, classname, sizeof(classname)))
				continue;

			if(StrEqual(classname, "weapon_knife"))
				continue;
		}

		RemovePlayerItem(client, weapon);
		RemoveEdict(weapon);
	}
}

stock int GetWeaponSlot(int weapon)
{
	if(!IsValidEdict(weapon))
		return SLOT_NONE;

	char classname[30];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return SLOT_NONE; // Can't get class name

	if(StrContains(classname, "weapon_") == -1)
		return SLOT_NONE; // Not a weapon

	if(StrEqual(classname, "weapon_knife"))
		return SLOT_MELEE;

	int i;

	for(i = 0; i < sizeof(weapons_primary); i++)
	{
		if(StrEqual(classname, weapons_primary[i]))
			return SLOT_PRIMARY;
	}

	for(i = 0; i < sizeof(weapons_secondary); i++)
	{
		if(StrEqual(classname, weapons_secondary[i]))
			return SLOT_SECONDARY;
	}

	for(i = 0; i < sizeof(weapons_grenade); i++)
	{
		if(StrEqual(classname, weapons_grenade[i]))
			return SLOT_GRENADE;
	}

	return SLOT_NONE; // Unknown weapon
}