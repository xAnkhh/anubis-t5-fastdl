#include common_scripts\utility;
#include maps\mp\_utility;

// Anubis for Plutonium T5 multiplayer.
// Source is split for editing; tools/build.sh joins every file into one script.

main()
{
	an_rounds_main();
}

init()
{
	level.an_build = an_build();
	level.an_accent = ( 0.72, 0.09, 0.11 );
	level.an_strings = [];
	level.an_string_count = 0;

	precacheShader( "white" );

	an_movement_init();
	an_rounds_init();
	an_roles_init();
	level thread an_server_dvars();
	level thread an_bot_init();
	level thread an_vote_watch();
	if ( getdvar( "g_gametype" ) == "sd" )
		level thread an_sui_watch();
	level thread an_on_connect();

	level.an_old_player_damage = level.callbackPlayerDamage;
	level.callbackPlayerDamage = ::an_player_damage;

	an_log( "init build " + level.an_build + " map " + getdvar( "mapname" ) + " gametype " + getdvar( "g_gametype" ) + " dedicated " + getdvar( "dedicated" ) + " onlinegame " + level.onlineGame );
}

an_build()
{
	return "14";
}

an_on_connect()
{
	for ( ;; )
	{
		level waittill( "connected", player );
		if ( player isDemoClient() )
			continue;
		player thread an_end_grace_on_death();
		if ( player an_is_bot() )
		{
			player thread an_bot_connected();
			continue;
		}
		player thread an_player_connected();
	}
}

an_player_connected()
{
	self endon( "disconnect" );
	self.an_menu_open = false;
	self an_menu_register_commands();
	self thread an_menu_input();
	self thread an_menu_close_on_death();
	self thread an_menu_close_on_end();
	self thread an_weapons_player();
	self thread an_class_change_watch();
	self an_bind_register();
	self an_role_announce();
	self thread an_autoload();
	an_log( "player armed " + self.name + " guid " + self getguid() + " host " + an_bool( self ishost() ) + " role " + self an_role() );
}

an_is_bot()
{
	if ( isDefined( self.pers ) && isDefined( self.pers["isBot"] ) && self.pers["isBot"] )
		return true;
	// test clients carry "bot" in their guid (Plutonium T5 community mods rely on this)
	return isSubStr( an_guid( self ), "bot" );
}

an_is_dedicated()
{
	d = getdvar( "dedicated" );
	return d != "" && d != "0" && d != "listen server";
}

// Dvar check: which Plutonium T5 dvars exist and what the script can set (NOTES 6/7).
an_server_dvars()
{
	wait 0.05;
	an_try_set( "sv_enableBounces", "1" );
	an_log( "plugin: weapons " + getdvar( "an_weaponsPatched" ) + ", wallbang " + getdvar( "bg_surfacePenetrationPatched" ) + " (bg_surfacePenetration " + getdvar( "bg_surfacePenetration" ) + ")" );
	names = strTok( "bulletrange sv_enableBounces sv_allAnglesBounces sv_terrainEdgeBounces sv_enableDoubleTaps g_playerCollision g_playerEjection jump_slowdownEnable player_sprintUnlimited bg_fallDamageMinHeight bg_ladder_yawcap bg_prone_yawcap player_useRadius penetrationCount perk_bulletPenetrationMultiplier bulletrange sv_cheats scr_allowFileIo", " " );
	line = "dvars";
	for ( i = 0; i < names.size; i++ )
		line = line + " " + names[i] + "=[" + getdvar( names[i] ) + "]";
	an_log( line );
}

an_try_set( name, value )
{
	setdvar( name, value );
}

an_bool( b )
{
	if ( b )
		return "1";
	return "0";
}

an_log( text )
{
	logPrint( "ANUBIS;" + text + "\n" );
	level thread an_log_file( text );
}

// Copy of the log in scriptdata (private matches may have no games_mp.log).
an_log_file( text )
{
	file = fs_fopen( "anubis/log.txt", "append" );
	if ( !isDefined( file ) )
		return;
	fs_writeline( file, getTime() + " " + text );
	fs_fclose( file );
}

// Text through one place so new strings can be counted (configstring budget).
an_set_text( elem, text )
{
	if ( isDefined( elem.an_text ) && elem.an_text == text )
		return;
	elem.an_text = text;
	if ( !isDefined( level.an_strings[ text ] ) )
	{
		level.an_strings[ text ] = true;
		level.an_string_count++;
		if ( level.an_string_count % 50 == 0 )
			an_log( "menu strings " + level.an_string_count );
	}
	elem setText( text );
}

// Killstreaks and maps.

an_give_killstreaks()
{
	if ( !isAlive( self ) )
		return;
	if ( !isDefined( self.killstreak ) )
	{
		self iPrintLn( "No killstreaks in this class" );
		return;
	}
	given = 0;
	for ( i = 0; i < 3; i++ )
	{
		if ( !isDefined( self.killstreak[i] ) )
			continue;
		type = maps\mp\gametypes\_hardpoints::getKillstreakByMenuName( self.killstreak[i] );
		if ( !isDefined( type ) )
			continue;
		self thread maps\mp\gametypes\_hardpoints::giveKillstreak( type, undefined, false, true );
		given++;
	}
	an_log( "killstreaks gave " + given + " to " + self.name );
}

// Every killstreak a player can earn in T5 (stock _hardpoints registrations;
// the drop variants are left out).
an_killstreak_list()
{
	all = strTok( "radar_mp rcbomb_mp counteruav_mp auto_tow_mp supply_drop_mp napalm_mp autoturret_mp mortar_mp helicopter_comlink_mp m220_tow_mp airstrike_mp radardirection_mp helicopter_gunner_mp m202_flash_mp minigun_mp dogs_mp helicopter_player_firstperson_mp", " " );
	list = [];
	for ( i = 0; i < all.size; i++ )
		if ( isDefined( level.killstreaks[ all[i] ] ) )
			list[ list.size ] = all[i];
	return list;
}

an_killstreak_name( type )
{
	switch ( type )
	{
		case "radar_mp": return "Spy Plane";
		case "rcbomb_mp": return "RC-XD";
		case "counteruav_mp": return "Counter-Spy Plane";
		case "auto_tow_mp": return "SAM Turret";
		case "supply_drop_mp": return "Care Package";
		case "napalm_mp": return "Napalm Strike";
		case "autoturret_mp": return "Sentry Gun";
		case "mortar_mp": return "Mortar Team";
		case "helicopter_comlink_mp": return "Attack Helicopter";
		case "m220_tow_mp": return "Valkyrie Rockets";
		case "airstrike_mp": return "Rolling Thunder";
		case "radardirection_mp": return "Blackbird";
		case "helicopter_gunner_mp": return "Chopper Gunner";
		case "m202_flash_mp": return "Grim Reaper";
		case "minigun_mp": return "Death Machine";
		case "dogs_mp": return "Attack Dogs";
		case "helicopter_player_firstperson_mp": return "Gunship";
	}
	return type;
}

an_killstreak_equipped( type )
{
	if ( !isDefined( self.killstreak ) || !isDefined( level.killstreaks[ type ] ) )
		return false;
	for ( i = 0; i < 3; i++ )
		if ( isDefined( self.killstreak[i] ) && self.killstreak[i] == level.killstreaks[ type ].menuName )
			return true;
	return false;
}

an_give_killstreak( type )
{
	if ( !isAlive( self ) || !isDefined( level.killstreaks[ type ] ) )
		return;
	self thread maps\mp\gametypes\_hardpoints::giveKillstreak( type, undefined, false, true );
	self iPrintLn( an_killstreak_name( type ) + " given" );
	an_log( "killstreak " + type + " to " + self.name );
}

an_map_list()
{
	return strTok( "mp_array mp_cracked mp_crisis mp_firingrange mp_duga mp_hanoi mp_cairo mp_havoc mp_cosmodrome mp_nuked mp_radiation mp_mountain mp_villa mp_russianbase mp_berlinwall2 mp_discovery mp_kowloon mp_stadium mp_gridlock mp_hotel mp_outskirts mp_zoo mp_drivein mp_area51 mp_golfcourse mp_silo", " " );
}

an_map_name( map )
{
	switch ( map )
	{
		case "mp_array": return "Array";
		case "mp_cracked": return "Cracked";
		case "mp_crisis": return "Crisis";
		case "mp_firingrange": return "Firing Range";
		case "mp_duga": return "Grid";
		case "mp_hanoi": return "Hanoi";
		case "mp_cairo": return "Havana";
		case "mp_havoc": return "Jungle";
		case "mp_cosmodrome": return "Launch";
		case "mp_nuked": return "Nuketown";
		case "mp_radiation": return "Radiation";
		case "mp_mountain": return "Summit";
		case "mp_villa": return "Villa";
		case "mp_russianbase": return "WMD";
		case "mp_berlinwall2": return "Berlin Wall";
		case "mp_discovery": return "Discovery";
		case "mp_kowloon": return "Kowloon";
		case "mp_stadium": return "Stadium";
		case "mp_gridlock": return "Convoy";
		case "mp_hotel": return "Hotel";
		case "mp_outskirts": return "Stockpile";
		case "mp_zoo": return "Zoo";
		case "mp_drivein": return "Drive-In";
		case "mp_area51": return "Hangar 18";
		case "mp_golfcourse": return "Hazard";
		case "mp_silo": return "Silo";
	}
	return map;
}

an_load_map( map )
{
	maps = an_map_list();
	ok = false;
	for ( i = 0; i < maps.size; i++ )
		if ( maps[i] == map )
			ok = true;
	if ( !ok )
		return;
	if ( an_is_dedicated() )
	{
		// Dedicated: GSC map() does nothing there (T6/IW5 lesson); load it through the rotation.
		setdvar( "sv_maprotationcurrent", "map " + map );
		an_log( "server map load " + map );
		exitLevel( false );
		return;
	}
	an_log( "host map load " + map );
	cmdexec( "map " + map );
}

an_restart_map()
{
	an_log( "map restart" );
	map_restart( false );
}

// One bot: spawn, kick, setup (frozen) / unsetup (moves), move to crosshair / to me.
// Settings live in server dvars so they survive S&D rounds; a new map resets them.

an_bot_init()
{
	map = getdvar( "mapname" );
	if ( getdvar( "an_bot_map" ) != map )
	{
		setdvar( "an_bot_map", map );
		setdvar( "an_bot_setup", "0" );
		setdvar( "an_bot_pos", "" );
		setdvar( "an_bot_yaw", "" );
		setdvar( "an_sui_pos", "" );
		setdvar( "an_loop", "0" );
		setdvar( "an_bot_wanted", "1" );
		an_log( "new map " + map + ": bot settings back to defaults" );
	}
	level thread an_bot_auto();
}

// Like other trickshot servers: one bot joins by itself (unsetup by default) as soon
// as a human is on a team. Kick Bot stops that for the rest of the map.
an_bot_auto()
{
	level endon( "game_ended" );
	wait 3;
	for ( ;; )
	{
		if ( getdvar( "an_bot_wanted" ) != "0" && !isDefined( an_bot_get() ) )
		{
			team = an_human_team();
			if ( isDefined( team ) )
				an_bot_add( getOtherTeam( team ), "auto" );
		}
		wait 1;
	}
}

an_bot_get()
{
	if ( isDefined( level.an_bot ) && isPlayer( level.an_bot ) )
		return level.an_bot;
	for ( i = 0; i < level.players.size; i++ )
	{
		if ( level.players[i] an_is_bot() )
		{
			level.an_bot = level.players[i];
			return level.an_bot;
		}
	}
	return undefined;
}

an_bot_setup()
{
	return getdvar( "an_bot_setup" ) == "1";
}

an_bot_spawn()
{
	if ( isDefined( an_bot_get() ) )
	{
		self iPrintLn( "The bot is already here" );
		return;
	}
	team = "axis";
	if ( isDefined( self.pers["team"] ) && ( self.pers["team"] == "allies" || self.pers["team"] == "axis" ) )
		team = getOtherTeam( self.pers["team"] );
	setdvar( "an_bot_wanted", "1" );
	if ( an_bot_add( team, self.name ) )
		self iPrintLn( "Bot spawned" );
	else
		self iPrintLn( "Couldn't add a bot (server full?)" );
}

an_bot_add( team, by )
{
	level.an_bot_team = team;
	bot = addTestClient();
	if ( !isDefined( bot ) )
	{
		an_log( "bot add failed (" + by + ")" );
		return false;
	}
	bot.pers["isBot"] = true;
	level.an_bot = bot;
	an_log( "bot added team " + team + " by " + by );
	return true;
}

an_bot_kick()
{
	bot = an_bot_get();
	if ( !isDefined( bot ) )
		return;
	level.an_bot = undefined;
	setdvar( "an_bot_wanted", "0" );
	kick( bot getEntityNumber() );
	self iPrintLn( "Bot kicked" );
}

// Runs every time the bot (re)connects, including each S&D round restart.
an_bot_connected()
{
	self endon( "disconnect" );
	level.an_bot = self;
	if ( !isDefined( self.pers["team"] ) || ( self.pers["team"] != "allies" && self.pers["team"] != "axis" ) )
	{
		team = "axis";
		if ( isDefined( level.an_bot_team ) )
			team = level.an_bot_team;
		self thread maps\mp\gametypes\_bot::bot_spawn_think( team );
	}
	self thread an_bot_hold();
	self thread an_bot_late_spawn();
	if ( isAlive( self ) )
		self an_bot_spawned();
	for ( ;; )
	{
		self waittill( "spawned_player" );
		self an_bot_spawned();
	}
}

an_bot_spawned()
{
	an_log( "bot spawned, setup " + getdvar( "an_bot_setup" ) );
	self thread an_bot_pistol();
	if ( an_bot_setup() )
		self an_bot_to_saved_spot();
}

// Setup mode is re-applied every 0.25 s (the round start unfreezes everyone).
an_bot_hold()
{
	self endon( "disconnect" );
	was_setup = false;
	for ( ;; )
	{
		if ( isAlive( self ) )
		{
			if ( an_bot_setup() )
			{
				self freezeControls( true );
				was_setup = true;
			}
			else if ( was_setup )
			{
				self freezeControls( false );
				was_setup = false;
			}
		}
		wait 0.25;
	}
}

an_bot_toggle_setup()
{
	if ( an_bot_setup() )
		setdvar( "an_bot_setup", "0" );
	else
	{
		setdvar( "an_bot_setup", "1" );
		bot = an_bot_get();
		if ( isDefined( bot ) && isAlive( bot ) && getdvar( "an_bot_pos" ) == "" )
			an_bot_save_spot( bot.origin, bot.angles[1] );
	}
	an_log( "bot setup " + getdvar( "an_bot_setup" ) );
}

an_bot_move( to_crosshair )
{
	bot = an_bot_get();
	if ( !isDefined( bot ) || !isAlive( bot ) )
	{
		self iPrintLn( "No live bot to move" );
		return;
	}
	if ( to_crosshair )
	{
		eye = self getEye();
		end = eye + vector_scale( anglesToForward( self getPlayerAngles() ), 100000 );
		trace = bulletTrace( eye, end, false, self );
		pos = trace["position"];
	}
	else
		pos = self.origin;
	yaw = self getPlayerAngles()[1];
	if ( to_crosshair )
		yaw = vectorToAngles( self.origin - pos )[1];
	an_bot_save_spot( pos, yaw );
	bot setOrigin( pos );
	bot setPlayerAngles( ( 0, yaw, 0 ) );
	an_log( "bot moved to " + pos );
}

an_bot_save_spot( pos, yaw )
{
	setdvar( "an_bot_pos", pos[0] + " " + pos[1] + " " + pos[2] );
	setdvar( "an_bot_yaw", "" + yaw );
}

an_bot_to_saved_spot()
{
	p = getdvar( "an_bot_pos" );
	if ( p == "" )
		return;
	t = strTok( p, " " );
	if ( t.size != 3 )
		return;
	self setOrigin( ( float( t[0] ), float( t[1] ), float( t[2] ) ) );
	self setPlayerAngles( ( 0, float( getdvar( "an_bot_yaw" ) ), 0 ) );
}

// S&D only spawns players that joined before the grace period ended (stock maySpawn,
// _globallogic_spawn.gsc:31). A bot added mid-round would sit dead until the next
// round, so it goes through the stock spawn path with hasSpawned set and a life.
// Bot only: its class is always valid (bot_spawn_think picks one); a human with
// class "" froze the T6 server this way.
an_bot_late_spawn()
{
	self endon( "disconnect" );
	level endon( "game_ended" );
	for ( tries = 0; tries < 3; tries++ )
	{
		for ( i = 0; i < 100; i++ )
		{
			if ( isAlive( self ) )
				return;
			if ( isDefined( self.pers["team"] ) && ( self.pers["team"] == "allies" || self.pers["team"] == "axis" ) && isDefined( self.class ) && self.class != "" && game["state"] == "playing" && !level.inPrematchPeriod )
				break;
			wait 0.1;
		}
		wait 0.5;
		if ( isAlive( self ) )
			return;
		if ( isDefined( self.waitingToSpawn ) && self.waitingToSpawn )
			continue;
		self.hasSpawned = true;
		if ( !isDefined( self.pers["lives"] ) || self.pers["lives"] < 1 )
			self.pers["lives"] = 1;
		an_log( "bot late spawn try " + ( tries + 1 ) );
		self thread maps\mp\gametypes\_globallogic_spawn::spawnClient();
		self waittill_any_timeout_an( 3, "spawned_player" );
	}
}

// common_scripts has no waittill_any_timeout in T5
waittill_any_timeout_an( timeout, name )
{
	self endon( name );
	wait timeout;
}

// Damage rules (Anubis, Ankh's T5 weapon list 2026-10-12):
// - humans only die to the map (falls out of the map, death triggers, crushes);
// - the bot never hurts anyone;
// - the bot dies in one hit to snipers, the ballistic knife (thrown), the tomahawk
//   and grenade launcher rounds that ricocheted first; any other hit only flinches it.
// Plus almost hits and afterhit prone.

an_player_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset )
{
	attacker_is_player = isDefined( eAttacker ) && isPlayer( eAttacker );
	if ( !self an_is_bot() )
	{
		if ( attacker_is_player && eAttacker an_is_bot() )
			return;
		if ( !an_is_map_death( sMeansOfDeath, sWeapon ) )
			return;
	}
	else if ( attacker_is_player && !eAttacker an_is_bot() )
	{
		eAttacker.an_last_hit_time = getTime();
		an_log( "bot hit by " + eAttacker.name + " " + sWeapon + " " + sMeansOfDeath );
		if ( an_is_killer( eAttacker, eInflictor, sWeapon, sMeansOfDeath ) )
		{
			iDamage = self.health + 1000;
			eAttacker thread an_on_bot_kill( self, sWeapon );
		}
		else
		{
			iDamage = 1;
			self thread an_restore_health();
		}
	}
	self [[ level.an_old_player_damage ]]( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset );
}

an_is_map_death( mod, weapon )
{
	switch ( mod )
	{
		case "MOD_FALLING":
		case "MOD_TRIGGER_HURT":
		case "MOD_CRUSH":
		case "MOD_HIT_BY_OBJECT":
			return true;
		case "MOD_SUICIDE":
			// a frag cooked to the end goes through as a suicide: not a map death
			return !isDefined( weapon ) || !isSubStr( weapon, "frag_grenade" );
	}
	return false;
}

an_is_killer( attacker, inflictor, weapon, mod )
{
	if ( !isDefined( weapon ) || weapon == "" || mod == "MOD_MELEE" )
		return false;
	if ( maps\mp\gametypes\_missions::getWeaponClass( weapon ) == "weapon_sniper" )
		return true;
	if ( isSubStr( weapon, "knife_ballistic" ) || isSubStr( weapon, "hatchet" ) )
		return true;
	if ( an_is_grenade_launcher( weapon ) )
	{
		if ( isDefined( inflictor ) && isDefined( inflictor.an_bounced ) )
			return true;
		// the round can be gone already when its explosion damage arrives
		if ( !isDefined( inflictor ) && isDefined( attacker.an_last_gl_bounce ) && getTime() - attacker.an_last_gl_bounce < 3000 )
			return true;
		an_log( "gl direct hit (no ricochet) by " + attacker.name );
	}
	return false;
}

an_restore_health()
{
	self endon( "disconnect" );
	waittillframeend;
	if ( isAlive( self ) )
		self.health = self.maxhealth;
}

// ---------------------------------------------------------------- after the bot dies

an_on_bot_kill( bot, weapon )
{
	self endon( "disconnect" );
	m = int( distance( self.origin, bot.origin ) * 0.0254 );
	an_log( "bot killed by " + self.name + " " + weapon + " " + m + "m" );
	if ( self.pers["an_afh"] == "stance" )
		self thread an_afterhit_prone( false );
	else if ( self.pers["an_afh"] == "instant" )
		self thread an_afterhit_prone( true );
}

// Stance changes one step per frame in the engine; "instant" crouches in the air
// and goes prone on landing.
an_afterhit_prone( instant )
{
	self endon( "disconnect" );
	self endon( "death" );
	for ( i = 0; i < 100 && !self isOnGround(); i++ )
	{
		if ( instant )
			self setStance( "crouch" );
		wait 0.05;
	}
	for ( i = 0; i < 20; i++ )
	{
		if ( self getStance() == "prone" )
			break;
		self setStance( "prone" );
		wait 0.05;
	}
}

// ---------------------------------------------------------------- almost hits

// Sniper shot whose crosshair impact lands within 45 units of the bot's feet,
// without hitting it (same rule as the Anubis T6 version).
an_almost_hit_watch()
{
	self endon( "disconnect" );
	self endon( "death" );
	self notify( "an_almost_hit_watch" );
	self endon( "an_almost_hit_watch" );
	for ( ;; )
	{
		self waittill( "weapon_fired" );
		weapon = self getCurrentWeapon();
		if ( weapon == "none" || weapon == "" || self.pers["an_ah"] != "1" || maps\mp\gametypes\_missions::getWeaponClass( weapon ) != "weapon_sniper" )
			continue;
		bot = an_bot_get();
		if ( !isDefined( bot ) || !isAlive( bot ) )
			continue;
		fired = getTime();
		eye = self getEye();
		dir = anglesToForward( self getPlayerAngles() );
		feet = bot.origin;
		dist = distance( eye, feet );
		trace = bulletTrace( eye, eye + vector_scale( dir, dist + 1000 ), true, self );
		self thread an_almost_hit_judge( bot, trace["position"], feet, fired );
	}
}

an_almost_hit_judge( bot, impact, feet, fired )
{
	self endon( "disconnect" );
	wait 0.1;
	if ( isDefined( self.an_last_hit_time ) && self.an_last_hit_time >= fired - 100 )
		return;
	if ( !isDefined( bot ) || !isAlive( bot ) )
		return;
	if ( distance( impact, feet ) > 45 )
		return;
	m = int( distance( self.origin, bot.origin ) * 0.0254 );
	self iPrintLnBold( "^7You Almost Hit! ^1[" + m + "m]" );
	for ( i = 0; i < level.players.size; i++ )
		if ( level.players[i] != self && !level.players[i] an_is_bot() )
			level.players[i] iPrintLn( self.name + " ^7almost hit! ^1[" + m + "m]" );
	an_log( "almost hit " + self.name + " " + m + "m" );
}

// ---------------------------------------------------------------- bot weapons

an_bot_pistol()
{
	self endon( "disconnect" );
	wait 0.1;
	if ( !isAlive( self ) )
		return;
	self takeAllWeapons();
	self giveWeapon( "m1911_mp" );
	self switchToWeapon( "m1911_mp" );
}

an_afterhit_cycle()
{
	switch ( self.pers["an_afh"] )
	{
		case "off": self.pers["an_afh"] = "stance"; break;
		case "stance": self.pers["an_afh"] = "instant"; break;
		default: self.pers["an_afh"] = "off"; break;
	}
}

an_almost_hit_toggle()
{
	if ( self.pers["an_ah"] == "1" )
		self.pers["an_ah"] = "0";
	else
		self.pers["an_ah"] = "1";
}

// Menu: script-drawn hud elements (T5 has no LUI; see NOTES.md section 5).
// Layout and colours follow the approved Anubis look (spine + card, black /
// grey / dark red), scaled to the 640x480 hud space.
// Budget: T5 has 31 current + 31 archival hud elems per player, so the menu
// uses 33 elements, created on open and destroyed on close.

an_menu_layout()
{
	l = spawnStruct();
	l.left = 37;
	l.spine_w = 29;
	l.card_x = 70;
	l.card_w = 293;
	l.pad = 15;
	l.header = 75;
	l.row = 21;
	l.rows = 10;
	l.footer = 34;
	l.height = l.header + l.row * l.rows + l.footer;
	l.top = int( ( 480 - l.height ) / 2 );
	l.rows_y = l.top + l.header;
	return l;
}

an_menu_register_commands()
{
	self notifyOnPlayerCommand( "an_up", "+actionslot 1" );
	self notifyOnPlayerCommand( "an_up_key", "+forward" );
	self notifyOnPlayerCommand( "an_down", "+actionslot 2" );
	self notifyOnPlayerCommand( "an_down_key", "+back" );
	self notifyOnPlayerCommand( "an_select", "+usereload" );
	self notifyOnPlayerCommand( "an_select", "+activate" );
	self notifyOnPlayerCommand( "an_select", "+gostand" );
	self notifyOnPlayerCommand( "an_back", "+melee" );
	self notifyOnPlayerCommand( "an_back", "+melee_zoom" );
	self notifyOnPlayerCommand( "an_back", "+stance" );
}

an_menu_input()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		cmd = self waittill_any_return( "an_up", "an_up_key", "an_down", "an_down_key", "an_select", "an_back" );
		if ( self.an_menu_open )
			an_log( "menu key " + cmd + " " + self.name );
		if ( !self.an_menu_open )
		{
			if ( cmd == "an_up" && self adsButtonPressed() && isAlive( self ) )
				self an_menu_open();
			continue;
		}
		if ( cmd == "an_up" || cmd == "an_up_key" )
			self an_menu_move( -1 );
		else if ( cmd == "an_down" || cmd == "an_down_key" )
			self an_menu_move( 1 );
		else if ( cmd == "an_select" )
			self an_menu_select();
		else if ( cmd == "an_back" )
			self an_menu_back();
	}
}

an_menu_close_on_death()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "death" );
		if ( self.an_menu_open )
			self an_menu_close();
	}
}

an_menu_close_on_end()
{
	self endon( "disconnect" );
	level waittill( "game_ended" );
	if ( self.an_menu_open )
		self an_menu_close();
}

an_menu_open()
{
	self.an_menu_open = true;
	self.an_page = "main";
	self.an_sel = 0;
	self.an_top = 0;
	self.an_stack = [];
	self an_menu_hold_player( true );
	self an_menu_create();
	self an_menu_render();
	an_log( "menu open " + self.name );
}

an_menu_close()
{
	self.an_menu_open = false;
	self an_menu_destroy();
	self an_menu_hold_player( false );
}

// Build 1 froze the player while the menu was open and the dpad stopped
// reaching the server (Ankh). The BO1 azza menu scrolls with the dpad without a
// freeze and only blanks action slot 1 (equipment) with " " while open, so this
// does the same: no movement (speed 0), equipment slot blanked, restored on close.
// Dvar an_menu_freeze 1 brings the old freeze back for comparison.
an_menu_hold_player( on )
{
	if ( getdvar( "an_menu_freeze" ) == "1" )
	{
		if ( on )
			self freezeControls( true );
		else if ( !level.gameEnded )
			self freezeControls( false );
		return;
	}
	if ( on )
	{
		self setMoveSpeedScale( 0 );
		self.an_menu_equipment = self an_equipment_weapon();
		self setActionSlot( 1, " " );
		return;
	}
	self setMoveSpeedScale( 1 );
	if ( isDefined( self.an_menu_equipment ) && self hasWeapon( self.an_menu_equipment ) )
		self setActionSlot( 1, "weapon", self.an_menu_equipment );
	self.an_menu_equipment = undefined;
}

an_equipment_weapon()
{
	list = strTok( "claymore_mp satchel_charge_mp tactical_insertion_mp scrambler_mp acoustic_sensor_mp camera_spike_mp", " " );
	for ( i = 0; i < list.size; i++ )
		if ( self hasWeapon( list[i] ) )
			return list[i];
	return undefined;
}

an_hud_rect( x, y, w, h, color, alpha, sort, archived )
{
	e = newClientHudElem( self );
	e.horzAlign = "left";
	e.vertAlign = "top";
	e.alignX = "left";
	e.alignY = "top";
	e.x = x;
	e.y = y;
	e.foreground = true;
	e.hideWhenInMenu = true;
	e.archived = archived;
	e.sort = sort;
	e setShader( "white", w, h );
	e.color = color;
	e.alpha = alpha;
	return e;
}

an_hud_text( x, y, alignX, font, scale, color, alpha, sort, archived )
{
	e = newClientHudElem( self );
	e.horzAlign = "left";
	e.vertAlign = "top";
	e.alignX = alignX;
	e.alignY = "middle";
	e.x = x;
	e.y = y;
	e.font = font;
	e.fontScale = scale;
	e.foreground = true;
	e.hideWhenInMenu = true;
	e.archived = archived;
	e.sort = sort;
	e.color = color;
	e.alpha = alpha;
	return e;
}

an_menu_create()
{
	l = an_menu_layout();
	self.an_l = l;
	accent = level.an_accent;
	text = ( 0.93, 0.93, 0.93 );
	dim = ( 0.56, 0.56, 0.56 );
	hx = l.card_x + l.pad;

	h = [];
	h["spine"] = self an_hud_rect( l.left, l.top, l.spine_w, l.height, ( 0.025, 0.025, 0.025 ), 0.96, 1, true );
	h["card"] = self an_hud_rect( l.card_x, l.top, l.card_w, l.height, ( 0.055, 0.055, 0.055 ), 0.93, 1, true );
	h["edge"] = self an_hud_rect( l.card_x, l.top, 48, 2, accent, 1, 3, true );
	h["eye"] = self an_hud_rect( l.left + 10, l.top + 12, 9, 9, accent, 1, 3, true );
	h["brand"] = self an_hud_text( hx, l.top + 13, "left", "small", 1.1, accent, 1, 4, true );
	h["build"] = self an_hud_text( l.card_x + l.card_w - l.pad, l.top + 13, "right", "small", 1.1, dim, 1, 4, true );
	h["title"] = self an_hud_text( hx, l.top + 35, "left", "objective", 1.7, text, 1, 4, true );
	h["path"] = self an_hud_text( hx, l.top + 55, "left", "small", 1.1, dim, 1, 4, true );
	h["rule"] = self an_hud_rect( hx, l.top + 66, 16, 2, accent, 1, 3, true );
	h["slab"] = self an_hud_rect( l.card_x, l.rows_y, l.card_w, l.row, ( 0.15, 0.15, 0.15 ), 0.95, 2, false );
	h["bar"] = self an_hud_rect( l.card_x, l.rows_y, 3, l.row, accent, 1, 3, false );
	h["marker"] = self an_hud_rect( l.left + 11, l.rows_y + 7, 7, 7, accent, 1, 3, false );
	h["thumb"] = self an_hud_rect( l.left + l.spine_w - 4, l.rows_y, 2, l.row, accent, 0.4, 3, true );
	h["hint"] = self an_hud_text( hx, l.rows_y + l.row * l.rows + 17, "left", "small", 1.0, dim, 1, 4, true );

	self.an_label = [];
	self.an_value = [];
	for ( i = 0; i < l.rows; i++ )
	{
		y = l.rows_y + i * l.row + int( l.row / 2 );
		self.an_label[i] = self an_hud_text( hx + 2, y, "left", "default", 1.3, text, 1, 4, false );
		self.an_value[i] = self an_hud_text( l.card_x + l.card_w - l.pad, y, "right", "default", 1.3, dim, 1, 4, false );
	}
	self.an_h = h;

	an_set_text( h["brand"], "A N U B I S" );
	an_set_text( h["build"], "BUILD " + level.an_build );
	an_set_text( h["hint"], "[ADS+UP] OPEN   [UP/DOWN] MOVE   [USE/JUMP] SELECT   [MELEE] BACK" );
}

an_menu_destroy()
{
	if ( !isDefined( self.an_h ) )
		return;
	keys = getArrayKeys( self.an_h );
	for ( i = 0; i < keys.size; i++ )
		self.an_h[ keys[i] ] destroy();
	for ( i = 0; i < self.an_label.size; i++ )
	{
		self.an_label[i] destroy();
		self.an_value[i] destroy();
	}
	self.an_h = undefined;
	self.an_label = [];
	self.an_value = [];
}

// ---------------------------------------------------------------- pages

an_row( kind, label, arg )
{
	r = spawnStruct();
	r.kind = kind;
	r.label = label;
	r.arg = arg;
	return r;
}

an_page_title( page )
{
	t = strTok( page, ":" );
	if ( t[0] == "dg" )
		return an_upper( an_drop_group_name( t[1] ) );
	if ( t[0] == "dw" )
		return an_upper( t[1] );
	switch ( page )
	{
		case "main": return "MAIN";
		case "killstreaks": return "KILLSTREAKS";
		case "weapon": return "WEAPON";
		case "drop": return "CANSWAP DROP";
		case "movement": return "MOVEMENT";
		case "bindables": return "BINDABLES";
		case "owner": return "OWNER";
		case "vote": return "NEXT MAP";
		case "utilities": return "UTILITIES";
		case "manager": return "MANAGER";
		case "bot": return "BOT";
		case "maps": return "MAPS";
	}
	return "ANUBIS";
}

an_page_rows( page )
{
	rows = [];
	t = strTok( page, ":" );
	if ( page == "vote" )
	{
		for ( i = 0; i < level.an_vote_choices.size; i++ )
		{
			label = "Random";
			if ( level.an_vote_choices[i] != "random" )
				label = an_map_name( level.an_vote_choices[i] );
			rows[ rows.size ] = an_row( "vote", label, i );
		}
	}
	else if ( page == "main" )
	{
		rows[ rows.size ] = an_row( "page", "Weapon", "weapon" );
		rows[ rows.size ] = an_row( "page", "Utilities", "utilities" );
		rows[ rows.size ] = an_row( "page", "Bindables", "bindables" );
		if ( self an_has_access() )
			rows[ rows.size ] = an_row( "page", "Manager", "manager" );
		if ( self an_is_owner() )
			rows[ rows.size ] = an_row( "page", "Owner", "owner" );
		if ( self an_has_access() )
			rows[ rows.size ] = an_row( "page", "Maps", "maps" );
		rows[ rows.size ] = an_row( "cmd", "Close", "close" );
	}
	else if ( page == "weapon" )
	{
		rows[ rows.size ] = an_row( "wset", "Instashoots", "is" );
		rows[ rows.size ] = an_row( "wset", "Always Canswap", "ac" );
		rows[ rows.size ] = an_row( "wset", "No Cockbacks", "nc" );
		rows[ rows.size ] = an_row( "wset", "Force Cockbacks", "fc" );
		rows[ rows.size ] = an_row( "wset", "One Bullet", "ob" );
		rows[ rows.size ] = an_row( "page", "Canswap Drop", "drop" );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( page == "drop" )
	{
		groups = an_drop_groups();
		for ( i = 0; i < groups.size; i++ )
			rows[ rows.size ] = an_row( "page", an_drop_group_name( groups[i] ), "dg:" + groups[i] );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( t[0] == "dg" )
	{
		guns = an_drop_guns( t[1] );
		for ( i = 0; i < guns.size; i++ )
			rows[ rows.size ] = an_row( "page", an_upper( guns[i] ), "dw:" + guns[i] );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( t[0] == "dw" )
	{
		rows[ rows.size ] = an_row( "drop", an_attachment_name( "none" ), t[1] + ":none" );
		atts = an_drop_attachments( t[1] );
		for ( i = 0; i < atts.size; i++ )
			rows[ rows.size ] = an_row( "drop", an_attachment_name( atts[i] ), t[1] + ":" + atts[i] );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( page == "utilities" )
	{
		rows[ rows.size ] = an_row( "page", "Killstreaks", "killstreaks" );
		rows[ rows.size ] = an_row( "afh", "Afterhit Prone", "afh" );
		rows[ rows.size ] = an_row( "ah", "Almost Hit Message", "ah" );
		rows[ rows.size ] = an_row( "cmd", "Save Settings", "save" );
		rows[ rows.size ] = an_row( "cmd", "Load Settings", "load" );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( page == "bindables" )
	{
		rows[ rows.size ] = an_row( "bindinfo", "Open This Menu", "menu" );
		rows[ rows.size ] = an_row( "bindinfo", "Give All Killstreaks", "killstreaks" );
		rows[ rows.size ] = an_row( "bindinfo", "Smooth Action", "smooth" );
		if ( self an_has_access() )
		{
			rows[ rows.size ] = an_row( "bindinfo", "Spawn Bot", "spawnbot" );
			rows[ rows.size ] = an_row( "bindinfo", "Move Bot to Crosshair", "tpbot" );
			rows[ rows.size ] = an_row( "bindinfo", "Setup / Unsetup Bot", "setupbot" );
		}
		rows[ rows.size ] = an_row( "info", "In the console: bind F1 spawnbot", "" );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( page == "owner" )
	{
		for ( i = 0; i < level.players.size; i++ )
		{
			p = level.players[i];
			if ( p an_is_bot() || p isDemoClient() || an_guid( p ) == an_owner_guid() )
				continue;
			rows[ rows.size ] = an_row( "mgr", p.name, an_guid( p ) );
		}
		if ( rows.size == 0 )
			rows[ rows.size ] = an_row( "info", "No other players here", "" );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( page == "killstreaks" )
	{
		rows[ rows.size ] = an_row( "cmd", "Give All Equipped", "killstreaks" );
		list = an_killstreak_list();
		for ( i = 0; i < list.size; i++ )
			rows[ rows.size ] = an_row( "ks", an_killstreak_name( list[i] ), list[i] );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( page == "manager" )
	{
		rows[ rows.size ] = an_row( "page", "Bot", "bot" );
		rows[ rows.size ] = an_row( "page", "Movement", "movement" );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( page == "movement" )
	{
		rows[ rows.size ] = an_row( "mv", "Ladder Spins", "ladder" );
		rows[ rows.size ] = an_row( "mv", "Prone Spins", "prone" );
		rows[ rows.size ] = an_row( "mv", "Bigger Use Radius", "use" );
		rows[ rows.size ] = an_row( "mv", "Lower Death Barriers", "barrier" );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( page == "bot" )
	{
		if ( isDefined( an_bot_get() ) )
			rows[ rows.size ] = an_row( "cmd", "Kick Bot", "bot_kick" );
		else
			rows[ rows.size ] = an_row( "cmd", "Spawn Bot", "bot_spawn" );
		rows[ rows.size ] = an_row( "cycle", "Bot Mode", "bot_mode" );
		rows[ rows.size ] = an_row( "cmd", "Move Bot to Crosshair", "bot_aim" );
		rows[ rows.size ] = an_row( "cmd", "Move Bot to Me", "bot_me" );
		rows[ rows.size ] = an_row( "cmd", "Save Sui Spot Here", "sui" );
		rows[ rows.size ] = an_row( "cmd", "Save Bot Settings", "bot_save" );
		rows[ rows.size ] = an_row( "cmd", "Load Bot Settings", "bot_load" );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( page == "maps" )
	{
		rows[ rows.size ] = an_row( "loop", "Restart Loop", "loop" );
		rows[ rows.size ] = an_row( "cmd", "Restart Map", "restart" );
		maps = an_map_list();
		for ( i = 0; i < maps.size; i++ )
			rows[ rows.size ] = an_row( "map", an_map_name( maps[i] ), maps[i] );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	return rows;
}

an_row_value( r )
{
	switch ( r.kind )
	{
		case "page": return ">";
		case "back": return "";
		case "map":
			if ( r.arg == getdvar( "mapname" ) )
				return "CURRENT";
			return "";
		case "ks":
			if ( self an_killstreak_equipped( r.arg ) )
				return "EQUIPPED";
			return "";
		case "wset":
			return self an_weapon_setting_text( r.arg );
		case "afh":
			return an_upper( self.pers["an_afh"] );
		case "mv":
			return an_movement_text( r.arg );
		case "bindinfo":
			return r.arg;
		case "loop":
			if ( getdvar( "an_loop" ) == "1" )
				return "ON";
			return "OFF";
		case "vote":
			n = an_vote_count( r.arg );
			if ( self an_my_vote() == r.arg )
				return "YOUR VOTE  " + n;
			return "" + n;
		case "mgr":
			if ( an_is_manager_guid( r.arg ) )
				return "MANAGER";
			return "OFF";
		case "ah":
			if ( self.pers["an_ah"] == "1" )
				return "ON";
			return "OFF";
		case "cycle":
			if ( r.arg == "bot_mode" )
			{
				if ( an_bot_setup() )
					return "SETUP";
				return "UNSETUP";
			}
			return "";
	}
	return "";
}

an_menu_render()
{
	if ( !self.an_menu_open || !isDefined( self.an_h ) )
		return;
	l = self.an_l;
	rows = self an_page_rows( self.an_page );
	self.an_rows = rows;
	if ( self.an_sel >= rows.size )
		self.an_sel = rows.size - 1;
	if ( self.an_sel < 0 )
		self.an_sel = 0;
	if ( self.an_sel < self.an_top )
		self.an_top = self.an_sel;
	if ( self.an_sel >= self.an_top + l.rows )
		self.an_top = self.an_sel - l.rows + 1;

	h = self.an_h;
	an_set_text( h["title"], an_page_title( self.an_page ) );
	path = "MAIN";
	for ( i = 0; i < self.an_stack.size; i++ )
		if ( self.an_stack[i] != "main" )
			path = path + "  /  " + an_page_title( self.an_stack[i] );
	if ( self.an_page != "main" )
		path = path + "  /  " + an_page_title( self.an_page );
	if ( self.an_page == "vote" )
		path = "VOTE  /  " + an_vote_seconds_left() + "S LEFT";
	an_set_text( h["path"], path );

	for ( i = 0; i < l.rows; i++ )
	{
		idx = self.an_top + i;
		if ( idx >= rows.size )
		{
			self.an_label[i].alpha = 0;
			self.an_value[i].alpha = 0;
			continue;
		}
		r = rows[idx];
		sel = ( idx == self.an_sel );
		label = r.label;
		if ( r.kind == "back" )
			label = "<   " + label;
		an_set_text( self.an_label[i], label );
		self.an_label[i].alpha = 1;
		if ( ( r.kind == "back" || r.kind == "info" ) && !sel )
			self.an_label[i].color = ( 0.56, 0.56, 0.56 );
		else
			self.an_label[i].color = ( 0.93, 0.93, 0.93 );
		if ( sel )
			self.an_label[i].x = l.card_x + l.pad + 8;
		else
			self.an_label[i].x = l.card_x + l.pad + 2;

		v = an_row_value( r );
		an_set_text( self.an_value[i], v );
		self.an_value[i].alpha = 1;
		if ( r.kind == "cycle" || v == "CURRENT" || v == "EQUIPPED" || ( ( r.kind == "wset" || r.kind == "afh" || r.kind == "ah" || r.kind == "mv" || r.kind == "loop" || r.kind == "mgr" ) && v != "OFF" ) || ( r.kind == "vote" && self an_my_vote() == r.arg ) )
			self.an_value[i].color = level.an_accent;
		else if ( sel )
			self.an_value[i].color = ( 0.93, 0.93, 0.93 );
		else
			self.an_value[i].color = ( 0.56, 0.56, 0.56 );
	}

	y = l.rows_y + ( self.an_sel - self.an_top ) * l.row;
	h["slab"].y = y;
	h["bar"].y = y;
	h["marker"].y = y + 7;

	if ( rows.size > l.rows )
	{
		track = l.row * l.rows;
		size = int( track * l.rows / rows.size );
		h["thumb"] setShader( "white", 2, size );
		h["thumb"].y = l.rows_y + int( ( track - size ) * self.an_top / ( rows.size - l.rows ) );
		h["thumb"].alpha = 0.4;
	}
	else
		h["thumb"].alpha = 0;
}

an_menu_move( dir )
{
	if ( !isDefined( self.an_rows ) || self.an_rows.size == 0 )
		return;
	self.an_sel = self.an_sel + dir;
	if ( self.an_sel < 0 )
		self.an_sel = self.an_rows.size - 1;
	else if ( self.an_sel >= self.an_rows.size )
		self.an_sel = 0;
	self an_menu_render();
}

an_menu_back()
{
	if ( self.an_page == "vote" )
		return;
	if ( self.an_stack.size == 0 )
	{
		self an_menu_close();
		return;
	}
	prev = self.an_stack[ self.an_stack.size - 1 ];
	self.an_stack[ self.an_stack.size - 1 ] = undefined;
	self.an_page = prev;
	self.an_sel = 0;
	self.an_top = 0;
	self an_menu_render();
}

an_menu_select()
{
	if ( !isDefined( self.an_rows ) || self.an_sel >= self.an_rows.size )
		return;
	r = self.an_rows[ self.an_sel ];
	switch ( r.kind )
	{
		case "page":
			self.an_stack[ self.an_stack.size ] = self.an_page;
			self.an_page = r.arg;
			self.an_sel = 0;
			self.an_top = 0;
			break;
		case "back":
			self an_menu_back();
			return;
		case "map":
			self an_do_command( "map", r.arg );
			break;
		case "ks":
		case "wset":
		case "afh":
		case "ah":
		case "drop":
		case "mv":
		case "loop":
		case "mgr":
			self an_do_command( r.kind, r.arg );
			break;
		case "vote":
			self an_vote_cast( r.arg );
			return;
		case "info":
		case "bindinfo":
			break;
		default:
			if ( r.arg == "close" )
			{
				self an_menu_close();
				return;
			}
			self an_do_command( r.arg, "" );
			break;
	}
	self an_menu_render();
}

// Every action goes through here so access is checked on the server side.
an_do_command( cmd, arg )
{
	host_only = ( cmd == "map" || cmd == "restart" || cmd == "mv" || cmd == "loop" || cmd == "sui" || isSubStr( cmd, "bot_" ) );
	if ( host_only && !self an_has_access() )
	{
		self iPrintLn( "Only managers can use that" );
		return;
	}
	if ( cmd == "mgr" && !self an_is_owner() )
	{
		self iPrintLn( "Only the owner can use that" );
		return;
	}
	an_log( "cmd " + cmd + " " + arg + " by " + self.name );
	switch ( cmd )
	{
		case "killstreaks": self an_give_killstreaks(); break;
		case "ks": self an_give_killstreak( arg ); break;
		case "wset": self an_weapon_setting_cycle( arg ); break;
		case "afh": self an_afterhit_cycle(); break;
		case "ah": self an_almost_hit_toggle(); break;
		case "save": self an_save_personal(); break;
		case "load": self an_load_personal( false ); break;
		case "bot_save": self an_save_bot(); break;
		case "bot_load": self an_load_bot(); break;
		case "sui": self an_sui_save(); break;
		case "loop": an_loop_toggle(); break;
		case "mgr": an_manager_toggle( arg ); break;
		case "mv":
			if ( arg == "barrier" )
				an_barrier_cycle();
			else
				an_movement_toggle( arg );
			break;
		case "drop":
			t = strTok( arg, ":" );
			self an_drop_weapon( t[0], t[1] );
			break;
		case "bot_spawn": self an_bot_spawn(); break;
		case "bot_kick": self an_bot_kick(); break;
		case "bot_mode": self an_bot_toggle_setup(); break;
		case "bot_aim": self an_bot_move( true ); break;
		case "bot_me": self an_bot_move( false ); break;
		case "restart": self an_restart_map(); break;
		case "map": self an_load_map( arg ); break;
	}
}

// Movement settings (Anubis):
// always on: bounces, no player collision, no jump fatigue, unlimited sprint,
// no fall damage, +5% bounce boost.
// Manager -> Movement (host dvars, reset on a new map): ladder spins, prone spins,
// bigger use radius (default on), Lower Death Barriers (OFF / 250 ... 2000).

an_movement_init()
{
	map = getdvar( "mapname" );
	if ( getdvar( "an_mv_map" ) != map )
	{
		setdvar( "an_mv_map", map );
		setdvar( "an_mv_ladder", "1" );
		setdvar( "an_mv_prone", "1" );
		setdvar( "an_mv_use", "1" );
		setdvar( "an_mv_barrier", "0" );
	}
	if ( getdvar( "an_bounce_boost" ) == "" )
		setdvar( "an_bounce_boost", "1.05" );

	setdvar( "sv_enableBounces", "1" );
	setdvar( "g_playerCollision", "2" );
	setdvar( "g_playerEjection", "2" );
	setdvar( "jump_slowdownEnable", "0" );
	setdvar( "player_sprintUnlimited", "1" );
	setdvar( "bg_fallDamageMinHeight", "9998" );
	setdvar( "bg_fallDamageMaxHeight", "9999" );
	// Wallbang everything comes from the server plugin (bg_surfacePenetration);
	// the range is the dvar's maximum (registered max 65536 in t5mp.exe).
	setdvar( "bulletrange", "65536" );
	an_movement_apply();

	level thread an_barrier_init();
	level thread an_bounce_boost_loop();
}

an_movement_apply()
{
	if ( getdvar( "an_mv_ladder" ) == "1" )
		setdvar( "bg_ladder_yawcap", "360" );
	else
		setdvar( "bg_ladder_yawcap", "100" );
	if ( getdvar( "an_mv_prone" ) == "1" )
		setdvar( "bg_prone_yawcap", "360" );
	else
		setdvar( "bg_prone_yawcap", "45" );
	if ( getdvar( "an_mv_use" ) == "1" )
		setdvar( "player_useRadius", "175" );
	else
		setdvar( "player_useRadius", "128" );
}

an_movement_toggle( key )
{
	d = "an_mv_" + key;
	if ( getdvar( d ) == "1" )
		setdvar( d, "0" );
	else
		setdvar( d, "1" );
	an_movement_apply();
	an_log( "movement " + key + " = " + getdvar( d ) );
}

an_movement_text( key )
{
	if ( key == "barrier" )
	{
		v = getdvar( "an_mv_barrier" );
		if ( v == "0" || v == "" )
			return "OFF";
		return v;
	}
	if ( getdvar( "an_mv_" + key ) == "1" )
		return "ON";
	return "OFF";
}

// ---------------------------------------------------------------- death barriers

an_barrier_steps()
{
	return strTok( "0 250 500 750 1000 1250 1500 1750 2000", " " );
}

an_barrier_cycle()
{
	steps = an_barrier_steps();
	v = getdvar( "an_mv_barrier" );
	next = steps[0];
	for ( i = 0; i < steps.size; i++ )
		if ( steps[i] == v && i + 1 < steps.size )
			next = steps[ i + 1 ];
	setdvar( "an_mv_barrier", next );
	an_barrier_apply();
}

// Death triggers below the map centre are stored with their stock origin each
// round and moved down by the chosen amount (sky / hazard triggers above stay).
an_barrier_init()
{
	wait 0.5;
	level.an_barriers = [];
	if ( !isDefined( level.mapCenter ) )
		return;
	ents = getEntArray( "trigger_hurt", "classname" );
	for ( i = 0; i < ents.size; i++ )
	{
		if ( ents[i].origin[2] <= level.mapCenter[2] )
		{
			ents[i].an_origin = ents[i].origin;
			level.an_barriers[ level.an_barriers.size ] = ents[i];
		}
	}
	an_log( "barriers found " + level.an_barriers.size + " of " + ents.size + " death triggers" );
	an_barrier_apply();
}

an_barrier_apply()
{
	if ( !isDefined( level.an_barriers ) )
		return;
	amount = int( getdvar( "an_mv_barrier" ) );
	for ( i = 0; i < level.an_barriers.size; i++ )
		level.an_barriers[i].origin = level.an_barriers[i].an_origin - ( 0, 0, amount );
	an_log( "barriers lowered " + amount );
}

// ---------------------------------------------------------------- bounce boost

// A bounce turns a fast fall into upward speed in one frame; that frame gets +5%.
an_bounce_boost_loop()
{
	level endon( "game_ended" );
	for ( ;; )
	{
		wait 0.05;
		boost = float( getdvar( "an_bounce_boost" ) );
		if ( boost <= 1 )
			continue;
		for ( i = 0; i < level.players.size; i++ )
		{
			p = level.players[i];
			if ( !an_is_human( p ) || !isAlive( p ) )
				continue;
			v = p getVelocity();
			if ( isDefined( p.an_last_vz ) && p.an_last_vz < -200 && v[2] >= 50 && !p isOnGround() )
			{
				p setVelocity( ( v[0], v[1], v[2] * boost ) );
				an_log( "bounce boost " + p.name + " fall " + int( p.an_last_vz ) + " up " + int( v[2] ) );
				v = ( v[0], v[1], v[2] * boost );
			}
			p.an_last_vz = v[2];
		}
	}
}

// Roles: owner (fixed GUID) and managers (GUIDs in scriptdata/anubis/managers.txt,
// set by the owner in-game). Owner and managers get the host pages on a dedicated
// server; in a private match the host has them too.

// getguid() is a number in T5; comparing a number with a string matched every
// player (build 13 server log: three different GUIDs all got "owner"). All GUID
// comparisons use this string form.
an_guid( player )
{
	return "" + player getguid();
}

an_owner_guid()
{
	return "5112037";
}

an_roles_init()
{
	level.an_managers = [];
	text = an_file_read( "anubis/managers.txt" );
	if ( !isDefined( text ) )
		return;
	lines = strTok( text, "\n" );
	for ( i = 0; i < lines.size; i++ )
	{
		t = strTok( lines[i], " " );
		if ( t.size >= 1 && t[0] != "" )
			level.an_managers[ level.an_managers.size ] = t[0];
	}
	an_log( "managers loaded " + level.an_managers.size );
}

an_role()
{
	g = an_guid( self );
	if ( g == an_owner_guid() )
		return "owner";
	for ( i = 0; i < level.an_managers.size; i++ )
		if ( level.an_managers[i] == g )
			return "manager";
	return "";
}

an_is_owner()
{
	return self an_role() == "owner";
}

// Ankh 2026-10-12: manager is the default role. Dvar an_everyone_manager
// (default on; "0" = only the owner and listed managers) can change it live.
an_has_access()
{
	if ( self ishost() )
		return true;
	if ( getdvar( "an_everyone_manager" ) != "0" )
		return true;
	return self an_role() != "";
}

an_role_announce()
{
	role = self an_role();
	if ( role == "" || isDefined( self.pers["an_announced"] ) )
		return;
	self.pers["an_announced"] = true;
	tag = "^4MANAGER";
	if ( role == "owner" )
		tag = "^1OWNER";
	iPrintLn( tag + "  ^7" + self.name + " joined" );
	an_log( "role announce " + self.name + " " + role );
}

an_manager_toggle( guid )
{
	if ( guid == an_owner_guid() )
		return;
	list = [];
	found = false;
	for ( i = 0; i < level.an_managers.size; i++ )
	{
		if ( level.an_managers[i] == guid )
			found = true;
		else
			list[ list.size ] = level.an_managers[i];
	}
	if ( !found )
		list[ list.size ] = guid;
	level.an_managers = list;
	text = "";
	for ( i = 0; i < list.size; i++ )
		text = text + list[i] + " " + an_player_name_by_guid( list[i] ) + "\n";
	an_file_write( "anubis/managers.txt", text );
	p = an_player_by_guid( guid );
	if ( isDefined( p ) )
	{
		if ( found )
			iPrintLn( "^4MANAGER  ^7" + p.name + " removed" );
		else
			iPrintLn( "^4MANAGER  ^7" + p.name + " added" );
	}
	an_log( "managers now " + list.size + " (toggled " + guid + ")" );
}

an_player_by_guid( guid )
{
	for ( i = 0; i < level.players.size; i++ )
		if ( !level.players[i] an_is_bot() && an_guid( level.players[i] ) == guid )
			return level.players[i];
	return undefined;
}

an_player_name_by_guid( guid )
{
	p = an_player_by_guid( guid );
	if ( isDefined( p ) )
		return p.name;
	return "";
}

an_is_manager_guid( guid )
{
	for ( i = 0; i < level.an_managers.size; i++ )
		if ( level.an_managers[i] == guid )
			return true;
	return false;
}

// ---------------------------------------------------------------- files (Plutonium fs_*, sandboxed in scriptdata)

an_file_read( path )
{
	if ( !fs_testfile( path ) )
		return undefined;
	f = fs_fopen( path, "read" );
	if ( !isDefined( f ) )
		return undefined;
	text = fs_read( f );
	fs_fclose( f );
	return text;
}

an_file_write( path, text )
{
	f = fs_fopen( path, "write" );
	if ( !isDefined( f ) )
	{
		an_log( "file write failed " + path );
		return false;
	}
	fs_write( f, text );
	fs_fclose( f );
	return true;
}

// S&D flow (Anubis rules, stock T5 sd.gsc / _globallogic hooks):
// - bomb placed at a random site at round start, nobody can carry it;
// - auto plant at that site with 5 s left;
// - attackers wiped out after the plant -> defenders win now (stock waits for the bomb);
// - eliminations during the grace period end the round at once;
// - full 7 rounds: a winner that is already ahead gives the point to the other team;
// - humans can move during the countdown; short free window after the round ends;
// - always-on UAV for the human team; match bonus on the outcome screen; class change any time.

// Plutonium docs: replaceFunc belongs in main(), which runs before the stock scripts.
an_rounds_main()
{
	replaceFunc( maps\mp\gametypes\_globallogic_player::freezePlayerForRoundEnd, ::an_freeze_for_round_end );
}

an_rounds_init()
{
	level.an_old_dead_event = level.onDeadEvent;
	level.onDeadEvent = ::an_dead_event;
	level.an_old_end_game = level.onEndGame;
	level.onEndGame = ::an_on_end_game;
	game["strings"]["change_class"] = " ";

	level thread an_countdown_free();
	level thread an_uav_loop();
	if ( getdvar( "g_gametype" ) == "sd" )
	{
		level thread an_bomb_auto_place();
		level thread an_auto_plant();
	}
}

an_is_human( p )
{
	return isDefined( p ) && isPlayer( p ) && !p an_is_bot() && !p isDemoClient();
}

// ---------------------------------------------------------------- bomb

an_bomb_auto_place()
{
	level endon( "game_ended" );
	while ( !isDefined( level.sdBomb ) || !isDefined( level.bombZones ) || level.bombZones.size == 0 )
		wait 0.05;
	zone = level.bombZones[ randomInt( level.bombZones.size ) ];
	level.an_bomb_zone = zone;
	bomb = level.sdBomb;
	bomb maps\mp\gametypes\_gameobjects::allowCarry( "none" );
	bomb maps\mp\gametypes\_gameobjects::setVisibleTeam( "none" );
	bomb maps\mp\gametypes\_gameobjects::clearCarrier();
	// stock sd onDrop notifies its player argument unconditionally (sd.gsc:881); with
	// nobody carrying the bomb (placement and the auto plant) that is undefined
	bomb.onDrop = ::an_bomb_on_drop;
	start = zone.trigger.origin + ( 0, 0, 20 );
	ground = playerPhysicsTrace( start, start - ( 0, 0, 2000 ), false, undefined );
	bomb.safeOrigin = ground;
	bomb maps\mp\gametypes\_gameobjects::setDropped();
	an_log( "bomb placed at site " + zone.label + " " + ground );
}

an_bomb_on_drop( player )
{
}

an_auto_plant()
{
	level endon( "game_ended" );
	while ( !isDefined( level.an_bomb_zone ) )
		wait 0.05;
	for ( ;; )
	{
		wait 0.05;
		if ( level.bombPlanted || level.inPrematchPeriod )
			continue;
		if ( maps\mp\gametypes\_globallogic_utils::getTimeRemaining() > 5000 )
			continue;
		planter = an_alive_player( game["attackers"] );
		if ( !isDefined( planter ) )
			continue;
		zone = level.an_bomb_zone;
		zone [[ zone.onUse ]]( planter );
		an_log( "auto plant at site " + zone.label + " for " + planter.name );
		return;
	}
}

an_alive_player( team )
{
	for ( i = 0; i < level.players.size; i++ )
	{
		p = level.players[i];
		if ( isAlive( p ) && isDefined( p.pers["team"] ) && p.pers["team"] == team )
			return p;
	}
	return undefined;
}

// ---------------------------------------------------------------- round end rules

an_dead_event( team )
{
	if ( getdvar( "g_gametype" ) == "sd" && !level.bombExploded && !level.bombDefused && level.bombPlanted && team == game["attackers"] )
	{
		an_log( "attackers wiped out after the plant: round to " + game["defenders"] );
		// same steps as stock sd_endGameWithKillcam (no direct sd.gsc call: this script loads in every mode)
		level thread maps\mp\gametypes\_killcam::startLastKillcam();
		[[ level._setTeamScore ]]( game["defenders"], [[ level._getTeamScore ]]( game["defenders"] ) + 1 );
		thread maps\mp\gametypes\_globallogic::endGame( game["defenders"], game["strings"][ game["attackers"] + "_eliminated" ] );
		return;
	}
	[[ level.an_old_dead_event ]]( team );
}

// Any death during the grace period ends it, so eliminations end the round at once.
an_end_grace_on_death()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "death" );
		if ( level.inGracePeriod && !level.gameEnded )
		{
			level.inGracePeriod = false;
			an_log( "death during grace period: grace ended" );
			level thread maps\mp\gametypes\_globallogic::updateTeamStatus();
		}
	}
}

// Runs inside stock endGame before it counts the round (roundswon[winner]++).
an_on_end_game( winner )
{
	if ( isDefined( level.an_old_end_game ) )
		[[ level.an_old_end_game ]]( winner );
	if ( getdvar( "g_gametype" ) != "sd" || !isDefined( winner ) || ( winner != "allies" && winner != "axis" ) )
		return;
	other = getOtherTeam( winner );
	if ( game["roundswon"][ winner ] > game["roundswon"][ other ] )
	{
		// stock sd_endGame already added the winner's team score point: move it
		[[ level._setTeamScore ]]( winner, [[ level._getTeamScore ]]( winner ) - 1 );
		[[ level._setTeamScore ]]( other, [[ level._getTeamScore ]]( other ) + 1 );
		game["roundswon"][ winner ]--;
		game["roundswon"][ other ]++;
		an_log( "round point moved from " + winner + " to " + other );
	}
	an_match_bonus( winner );
}

an_match_bonus( winner )
{
	passed = maps\mp\gametypes\_globallogic_utils::getTimePassed() / 1000;
	if ( passed > 1200 )
		passed = 1200;
	for ( i = 0; i < level.players.size; i++ )
	{
		p = level.players[i];
		if ( !an_is_human( p ) || !isDefined( p.pers["team"] ) )
			continue;
		scale = 0.5;
		if ( p.pers["team"] == winner )
			scale = 1;
		p.matchBonus = int( scale * passed / 60 * p maps\mp\gametypes\_rank::getSPM() );
	}
}

// Stock freeze, but humans keep moving for an_round_end_delay seconds (default 0.15).
an_freeze_for_round_end()
{
	self clearLowerMessage();
	self closeMenu();
	self closeInGameMenu();
	currentWeapon = self getCurrentWeapon();
	if ( maps\mp\gametypes\_hardpoints::isKillstreakWeapon( currentWeapon ) && !maps\mp\gametypes\_killstreak_weapons::isHeldKillstreakWeapon( currentWeapon ) )
		self takeWeapon( currentWeapon );
	self thread an_freeze_after_delay();
}

an_freeze_after_delay()
{
	self endon( "disconnect" );
	delay = 0.15;
	if ( getdvar( "an_round_end_delay" ) != "" )
		delay = float( getdvar( "an_round_end_delay" ) );
	if ( an_is_human( self ) && delay > 0 )
		wait delay;
	self freeze_player_controls( true );
}

// ---------------------------------------------------------------- countdown, UAV, class change

an_countdown_free()
{
	level endon( "game_ended" );
	while ( !isDefined( level.inPrematchPeriod ) )
		wait 0.05;
	while ( level.inPrematchPeriod )
	{
		for ( i = 0; i < level.players.size; i++ )
			if ( an_is_human( level.players[i] ) && isAlive( level.players[i] ) && !( isDefined( level.players[i].an_menu_open ) && level.players[i].an_menu_open ) )
				level.players[i] freeze_player_controls( false );
		wait 0.05;
	}
}

// Always-on sweeping UAV for the team the humans are on.
an_uav_loop()
{
	level endon( "game_ended" );
	wait 1;
	for ( ;; )
	{
		team = an_human_team();
		if ( isDefined( team ) && !maps\mp\_radar::teamHasSatellite( team ) )
			maps\mp\_radar::setTeamSpyplaneWrapper( team, 1 );
		wait 5;
	}
}

an_human_team()
{
	count = [];
	count["allies"] = 0;
	count["axis"] = 0;
	for ( i = 0; i < level.players.size; i++ )
	{
		p = level.players[i];
		if ( an_is_human( p ) && isDefined( p.pers["team"] ) && isDefined( count[ p.pers["team"] ] ) )
			count[ p.pers["team"] ]++;
	}
	if ( count["allies"] == 0 && count["axis"] == 0 )
		return undefined;
	if ( count["axis"] > count["allies"] )
		return "axis";
	return "allies";
}

// Picking a class mid-life gives it right away (stock only does that in the grace
// period, _globallogic_ui.gsc:691; otherwise it waits for the next spawn).
an_class_change_watch()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "changed_class" );
		waittillframeend;
		if ( !isAlive( self ) || level.gameEnded || !isDefined( self.pers["class"] ) )
			continue;
		// stock already gives it in the grace period before any combat
		if ( level.inGracePeriod && !( isDefined( self.hasDoneCombat ) && self.hasDoneCombat ) )
			continue;
		self maps\mp\gametypes\_class::setClass( self.pers["class"] );
		self.tag_stowed_back = undefined;
		self.tag_stowed_hip = undefined;
		self maps\mp\gametypes\_class::giveLoadout( self.pers["team"], self.pers["class"] );
		self maps\mp\gametypes\_hardpoints::giveOwnedKillstreak();
		self thread an_record_weapon_options();
		an_log( "class change " + self.name + " " + self.pers["class"] );
	}
}

// Save / load (Anubis rules): personal settings saved per GUID on the server
// (scriptdata/anubis/player_<guid>.txt), loaded by themselves on join; never saved
// by themselves. Bot settings (setup, bot spot and sui spot for this map) are a
// separate manual save for managers. Restart loop, sui spot and bindable commands.

an_personal_keys()
{
	return strTok( "is ac ob nc fc afh ah", " " );
}

an_player_file()
{
	return "anubis/player_" + self getguid() + ".txt";
}

an_save_personal()
{
	keys = an_personal_keys();
	text = "";
	for ( i = 0; i < keys.size; i++ )
		text = text + keys[i] + "=" + self.pers[ "an_" + keys[i] ] + "\n";
	if ( an_file_write( self an_player_file(), text ) )
		self iPrintLn( "Settings saved" );
	an_log( "save " + self.name );
}

an_load_personal( quiet )
{
	text = an_file_read( self an_player_file() );
	if ( !isDefined( text ) )
	{
		if ( !quiet )
			self iPrintLn( "No saved settings yet" );
		return;
	}
	keys = an_personal_keys();
	lines = strTok( text, "\n" );
	n = 0;
	for ( i = 0; i < lines.size; i++ )
	{
		t = strTok( lines[i], "=" );
		if ( t.size == 0 )
			continue;
		v = "";
		if ( t.size > 1 )
			v = t[1];
		for ( k = 0; k < keys.size; k++ )
		{
			if ( keys[k] == t[0] && an_valid_setting( t[0], v ) )
			{
				self.pers[ "an_" + t[0] ] = v;
				n++;
			}
		}
	}
	self an_one_bullet_now();
	self iPrintLn( "Saved settings loaded (" + n + ")" );
	an_log( "load " + self.name + " " + n + " values" );
}

an_valid_setting( key, v )
{
	switch ( key )
	{
		case "afh": return v == "off" || v == "stance" || v == "instant";
		case "ah": return v == "0" || v == "1";
	}
	// weapon settings: "", "all" or a gun base name (letters / digits only)
	for ( i = 0; i < v.size; i++ )
		if ( !isSubStr( "abcdefghijklmnopqrstuvwxyz0123456789", v[i] ) )
			return false;
	return true;
}

// Once per player per map (pers survives S&D rounds, a new map clears it).
an_autoload()
{
	self endon( "disconnect" );
	if ( isDefined( self.pers["an_autoloaded"] ) )
		return;
	self.pers["an_autoloaded"] = true;
	wait 1;
	if ( fs_testfile( self an_player_file() ) )
		self an_load_personal( true );
}

// ---------------------------------------------------------------- bot settings

an_save_bot()
{
	map = getdvar( "mapname" );
	text = "setup=" + getdvar( "an_bot_setup" ) + "\n";
	text = text + "pos_" + map + "=" + getdvar( "an_bot_pos" ) + "\n";
	text = text + "yaw_" + map + "=" + getdvar( "an_bot_yaw" ) + "\n";
	text = text + "sui_" + map + "=" + getdvar( "an_sui_pos" ) + "\n";
	old = an_file_read( "anubis/bot_settings.txt" );
	if ( isDefined( old ) )
	{
		lines = strTok( old, "\n" );
		for ( i = 0; i < lines.size; i++ )
		{
			k = strTok( lines[i], "=" )[0];
			if ( isSubStr( k, "_" ) && !isSubStr( k, "_" + map ) )
				text = text + lines[i] + "\n";
		}
	}
	if ( an_file_write( "anubis/bot_settings.txt", text ) )
		self iPrintLn( "Bot settings saved" );
	an_log( "bot save by " + self.name );
}

an_load_bot()
{
	text = an_file_read( "anubis/bot_settings.txt" );
	if ( !isDefined( text ) )
	{
		self iPrintLn( "No saved bot settings yet" );
		return;
	}
	map = getdvar( "mapname" );
	lines = strTok( text, "\n" );
	for ( i = 0; i < lines.size; i++ )
	{
		t = strTok( lines[i], "=" );
		if ( t.size < 2 )
			continue;
		switch ( t[0] )
		{
			case "setup":
				if ( t[1] == "0" || t[1] == "1" )
					setdvar( "an_bot_setup", t[1] );
				break;
		}
		if ( t[0] == "pos_" + map )
			setdvar( "an_bot_pos", t[1] );
		else if ( t[0] == "yaw_" + map )
			setdvar( "an_bot_yaw", t[1] );
		else if ( t[0] == "sui_" + map )
			setdvar( "an_sui_pos", t[1] );
	}
	bot = an_bot_get();
	if ( isDefined( bot ) && isAlive( bot ) && an_bot_setup() )
		bot an_bot_to_saved_spot();
	self iPrintLn( "Bot settings loaded" );
	an_log( "bot load by " + self.name );
}

// ---------------------------------------------------------------- sui spot

an_sui_save()
{
	p = self.origin;
	setdvar( "an_sui_pos", p[0] + " " + p[1] + " " + p[2] );
	self iPrintLn( "Sui spot saved here" );
	an_log( "sui spot " + p + " by " + self.name );
}

// Once the bomb is planted the bot moves to the sui spot and goes into setup.
an_sui_watch()
{
	level endon( "game_ended" );
	while ( !isDefined( level.bombPlanted ) || !level.bombPlanted )
		wait 0.1;
	p = getdvar( "an_sui_pos" );
	bot = an_bot_get();
	if ( p == "" || !isDefined( bot ) || !isAlive( bot ) )
		return;
	t = strTok( p, " " );
	if ( t.size != 3 )
		return;
	setdvar( "an_bot_setup", "1" );
	bot freezeControls( true );
	bot setOrigin( ( float( t[0] ), float( t[1] ), float( t[2] ) ) );
	an_log( "sui: bot moved to " + p );
}

// ---------------------------------------------------------------- restart loop

an_loop_toggle()
{
	if ( getdvar( "an_loop" ) == "1" )
		setdvar( "an_loop", "0" );
	else
		setdvar( "an_loop", "1" );
	an_log( "restart loop " + getdvar( "an_loop" ) );
}

// ---------------------------------------------------------------- bindable console commands

an_bind_list()
{
	return strTok( "menu spawnbot tpbot setupbot killstreaks smooth", " " );
}

an_bind_register()
{
	list = an_bind_list();
	for ( i = 0; i < list.size; i++ )
		self notifyOnPlayerCommand( "an_bind_" + list[i], list[i] );
	for ( i = 0; i < list.size; i++ )
		self thread an_bind_watch( list[i] );
}

an_bind_watch( name )
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "an_bind_" + name );
		an_log( "bind " + name + " by " + self.name );
		switch ( name )
		{
			case "menu":
				if ( !self.an_menu_open && isAlive( self ) )
					self an_menu_open();
				break;
			case "spawnbot":
				self an_do_command( "bot_spawn", "" );
				break;
			case "tpbot":
				self an_do_command( "bot_aim", "" );
				break;
			case "setupbot":
				self an_do_command( "bot_mode", "" );
				break;
			case "killstreaks":
				self an_do_command( "killstreaks", "" );
				break;
			case "smooth":
				if ( isAlive( self ) && !self.an_menu_open )
					self an_smooth_action();
				break;
		}
	}
}

// End-of-match map vote (Anubis): 3 random maps + Random, 15 s, inside the stock
// 30 s intermission (_globallogic.gsc: level.intermission, then exitLevel after
// scr_intermission_time). Restart Loop skips the vote; an empty server goes back to
// the first map of its rotation. Dedicated: the result goes into
// sv_maprotationcurrent for the stock exitLevel; private match: host console "map".

an_vote_watch()
{
	level waittill( "game_ended" );
	for ( i = 0; i < 600 && !( isDefined( level.intermission ) && level.intermission ); i++ )
		wait 0.1;
	if ( !isDefined( level.intermission ) || !level.intermission )
		return;

	if ( getdvar( "an_loop" ) == "1" )
	{
		an_next_map( getdvar( "mapname" ), "restart loop" );
		return;
	}
	humans = an_humans();
	if ( humans.size == 0 )
	{
		first = an_first_rotation_map();
		if ( isDefined( first ) )
			an_next_map( first, "empty server" );
		return;
	}

	level.an_vote_choices = an_vote_pick();
	level.an_votes = [];
	level.an_vote_end = getTime() + 15000;
	for ( i = 0; i < humans.size; i++ )
		humans[i] thread an_vote_open();
	an_log( "map vote " + level.an_vote_choices[0] + " " + level.an_vote_choices[1] + " " + level.an_vote_choices[2] + " random" );

	while ( getTime() < level.an_vote_end )
	{
		wait 0.5;
		humans = an_humans();
		for ( i = 0; i < humans.size; i++ )
			if ( isDefined( humans[i].an_menu_open ) && humans[i].an_menu_open && humans[i].an_page == "vote" )
				humans[i] an_menu_render();
	}

	winner = an_vote_result();
	humans = an_humans();
	for ( i = 0; i < humans.size; i++ )
		if ( isDefined( humans[i].an_menu_open ) && humans[i].an_menu_open )
			humans[i] an_menu_close();
	iPrintLnBold( "Next map: " + an_map_name( winner ) );
	an_next_map( winner, "vote" );
}

an_humans()
{
	list = [];
	for ( i = 0; i < level.players.size; i++ )
		if ( an_is_human( level.players[i] ) )
			list[ list.size ] = level.players[i];
	return list;
}

an_vote_pick()
{
	maps = an_map_list();
	pool = [];
	for ( i = 0; i < maps.size; i++ )
		if ( maps[i] != getdvar( "mapname" ) )
			pool[ pool.size ] = maps[i];
	picks = [];
	for ( n = 0; n < 3 && pool.size > 0; n++ )
	{
		k = randomInt( pool.size );
		picks[ picks.size ] = pool[k];
		rest = [];
		for ( i = 0; i < pool.size; i++ )
			if ( i != k )
				rest[ rest.size ] = pool[i];
		pool = rest;
	}
	picks[ picks.size ] = "random";
	return picks;
}

an_vote_count( idx )
{
	n = 0;
	keys = getArrayKeys( level.an_votes );
	for ( i = 0; i < keys.size; i++ )
		if ( level.an_votes[ keys[i] ] == idx )
			n++;
	return n;
}

an_vote_cast( idx )
{
	if ( !isDefined( level.an_vote_choices ) || getTime() >= level.an_vote_end )
		return;
	level.an_votes[ self getguid() + "_" + self getEntityNumber() ] = idx;
	an_log( "vote " + self.name + " " + level.an_vote_choices[ idx ] );
	self an_menu_render();
}

an_my_vote()
{
	k = self getguid() + "_" + self getEntityNumber();
	if ( isDefined( level.an_votes ) && isDefined( level.an_votes[k] ) )
		return level.an_votes[k];
	return -1;
}

an_vote_result()
{
	best = [];
	top = -1;
	for ( i = 0; i < level.an_vote_choices.size; i++ )
	{
		c = an_vote_count( i );
		if ( c > top )
		{
			top = c;
			best = [];
		}
		if ( c == top )
			best[ best.size ] = i;
	}
	pick = level.an_vote_choices[ best[ randomInt( best.size ) ] ];
	if ( pick == "random" )
	{
		maps = an_map_list();
		pick = maps[ randomInt( maps.size ) ];
		for ( i = 0; i < 10 && pick == getdvar( "mapname" ); i++ )
			pick = maps[ randomInt( maps.size ) ];
	}
	an_log( "vote result " + pick + " (" + top + " votes)" );
	return pick;
}

an_vote_open()
{
	self endon( "disconnect" );
	if ( isDefined( self.an_menu_open ) && self.an_menu_open )
		self an_menu_close();
	self.an_menu_open = true;
	self.an_page = "vote";
	self.an_sel = 0;
	self.an_top = 0;
	self.an_stack = [];
	self an_menu_create();
	self an_menu_render();
}

an_vote_seconds_left()
{
	s = int( ( level.an_vote_end - getTime() ) / 1000 );
	if ( s < 0 )
		s = 0;
	return s;
}

an_next_map( map, why )
{
	if ( an_is_dedicated() )
		setdvar( "sv_maprotationcurrent", "map " + map );
	else
		level thread an_listen_map_change( map );
	an_log( "next map " + map + " (" + why + ")" );
}

// Private match: the host's console loads it once the vote is over.
an_listen_map_change( map )
{
	wait 2;
	cmdexec( "map " + map );
}

an_first_rotation_map()
{
	t = strTok( getdvar( "sv_maprotation" ), " " );
	for ( i = 0; i + 1 < t.size; i++ )
		if ( t[i] == "map" )
			return t[ i + 1 ];
	return undefined;
}

// Weapon features (GSC versions; the engine-level ones come with the server plugin later):
// instashoots, always canswap, one bullet (OFF / one gun / ALL), canswap drop,
// ammo + equipment refills. Settings in self.pers, so they last for the map.

an_weapons_defaults()
{
	keys = strTok( "is ac ob nc fc", " " );
	for ( i = 0; i < keys.size; i++ )
		if ( !isDefined( self.pers[ "an_" + keys[i] ] ) )
			self.pers[ "an_" + keys[i] ] = "";
	if ( !isDefined( self.pers["an_afh"] ) )
		self.pers["an_afh"] = "off";
	if ( !isDefined( self.pers["an_ah"] ) )
		self.pers["an_ah"] = "1";
}

an_weapons_player()
{
	self endon( "disconnect" );
	self an_weapons_defaults();
	self thread an_equipment_refill();
	self thread an_gl_fire_watch();
	// S&D rounds spawn players before their threads start: arm the current life too.
	if ( isAlive( self ) )
		self an_weapons_spawned();
	for ( ;; )
	{
		self waittill( "spawned_player" );
		self an_weapons_spawned();
	}
}

an_weapons_spawned()
{
	self an_plugin_sync();
	self thread an_weapon_watch();
	self thread an_ammo_loop();
	self thread an_record_weapon_options();
	self thread an_almost_hit_watch();
}

// "psg1_acog_mp" -> "psg1" (dual wield guns keep their own name, e.g. "aspdw").
an_weapon_base( weapon )
{
	return strTok( weapon, "_" )[0];
}

an_setting_applies( key, weapon )
{
	v = self.pers[ "an_" + key ];
	if ( v == "" )
		return false;
	if ( v == "all" )
		return true;
	return an_weapon_base( weapon ) == v;
}

an_is_primary( weapon )
{
	list = self getWeaponsListPrimaries();
	for ( i = 0; i < list.size; i++ )
		if ( list[i] == weapon )
			return true;
	return false;
}

// Menu cycle: OFF -> the gun in hand -> ALL -> OFF.
an_weapon_setting_cycle( key )
{
	v = self.pers[ "an_" + key ];
	held = self getCurrentWeapon();
	if ( v == "" && held != "none" && self an_is_primary( held ) )
		v = an_weapon_base( held );
	else if ( v == "" || v != "all" )
		v = "all";
	else
		v = "";
	self.pers[ "an_" + key ] = v;
	// No cockbacks and force cockbacks never both on (the plugin also lets force win)
	if ( key == "nc" && v != "" )
		self.pers["an_fc"] = "";
	if ( key == "fc" && v != "" )
		self.pers["an_nc"] = "";
	if ( ( key == "nc" || key == "fc" ) && !an_weapons_plugin() )
		self iPrintLn( "Cockback settings only work on the Anubis server" );
	an_log( "setting " + key + " = " + v + " by " + self.name );
	self an_plugin_sync();
	if ( key == "ob" && v != "" )
		self an_one_bullet_now();
}

an_weapon_setting_text( key )
{
	v = self.pers[ "an_" + key ];
	if ( v == "" )
		return "OFF";
	return an_upper( v );
}

// ---------------------------------------------------------------- swap watcher

an_weapon_watch()
{
	self endon( "disconnect" );
	self endon( "death" );
	self notify( "an_weapon_watch" );
	self endon( "an_weapon_watch" );
	for ( ;; )
	{
		self waittill( "weapon_change", weapon );
		if ( !isDefined( weapon ) || weapon == "none" || !self an_is_primary( weapon ) )
			continue;
		self an_plugin_sync();
		if ( self.pers["an_ac"] != "" && !an_weapons_plugin() )
			self an_prime_canswaps( weapon );
		if ( self an_setting_applies( "ob", weapon ) )
			self setWeaponAmmoClip( weapon, 1 );
		if ( self an_setting_applies( "is", weapon ) && !an_weapons_plugin() )
		{
			self setSpawnWeapon( weapon );
			self thread an_instashoot_watch( weapon );
		}
	}
}

// Same method as the working BO1 Revolt menu and the Anubis T6 GSC version:
// first fire press during the pull-out -> drop and re-raise the gun at once.
an_instashoot_watch( weapon )
{
	self endon( "disconnect" );
	self endon( "death" );
	self notify( "an_instashoot" );
	self endon( "an_instashoot" );
	for ( i = 0; i < 40; i++ )
	{
		if ( self getCurrentWeapon() != weapon )
			return;
		if ( self attackButtonPressed() && !self isFiring() )
		{
			self disableWeapons();
			wait 0.05;
			self enableWeapons();
			an_log( "instashoot " + self.name + " " + weapon + " after " + ( i * 50 ) + " ms" );
			return;
		}
		wait 0.05;
	}
}

// Every other gun the setting covers is taken and given back (camo and ammo kept),
// so its next pull-out is a first raise (canswap).
an_prime_canswaps( held )
{
	list = self getWeaponsListPrimaries();
	for ( i = 0; i < list.size; i++ )
	{
		w = list[i];
		if ( w == held || !self an_setting_applies( "ac", w ) )
			continue;
		clip = self getWeaponAmmoClip( w );
		stock = self getWeaponAmmoStock( w );
		self takeWeapon( w );
		self giveWeapon( w, 0, self an_weapon_options( w ) );
		self setWeaponAmmoClip( w, clip );
		self setWeaponAmmoStock( w, stock );
	}
}

// Camo / reticle options of the class guns (stock giveLoadout passes them to giveWeapon).
an_record_weapon_options()
{
	self endon( "disconnect" );
	self.an_wopts = [];
	wait 0.05;
	if ( !isDefined( self.class ) || !isDefined( self.custom_class ) )
		return;
	c = self.class;
	if ( !isSubStr( c, "CLASS_CUSTOM" ) && !isSubStr( c, "CLASS_PRESTIGE" ) )
		return;
	n = int( c[ c.size - 1 ] ) - 1;
	if ( n == -1 )
		n = 9;
	if ( isSubStr( c, "CLASS_PRESTIGE" ) )
		n = n + 5;
	if ( !isDefined( self.custom_class[n] ) )
		return;
	cc = self.custom_class[n];
	if ( isDefined( cc["primary"] ) && isDefined( cc["primary_weapon_options"] ) )
		self.an_wopts[ cc["primary"] ] = int( cc["primary_weapon_options"] );
	if ( isDefined( cc["secondary"] ) && isDefined( cc["secondary_weapon_options"] ) )
		self.an_wopts[ cc["secondary"] ] = int( cc["secondary_weapon_options"] );
}

an_weapon_options( weapon )
{
	if ( isDefined( self.an_wopts ) && isDefined( self.an_wopts[ weapon ] ) )
		return self.an_wopts[ weapon ];
	return 0;
}

// ---------------------------------------------------------------- ammo

an_one_bullet_now()
{
	w = self getCurrentWeapon();
	if ( w != "none" && self an_setting_applies( "ob", w ) && self getWeaponAmmoClip( w ) > 1 )
		self setWeaponAmmoClip( w, 1 );
}

// One bullet holds the magazine at 1 (also after reloads); the reserve is refilled
// when it reaches its last magazine.
an_ammo_loop()
{
	self endon( "disconnect" );
	self endon( "death" );
	self notify( "an_ammo_loop" );
	self endon( "an_ammo_loop" );
	for ( ;; )
	{
		wait 0.1;
		w = self getCurrentWeapon();
		if ( w == "none" || !self an_is_primary( w ) )
			continue;
		if ( self an_setting_applies( "ob", w ) && self getWeaponAmmoClip( w ) > 1 )
			self setWeaponAmmoClip( w, 1 );
		if ( self getWeaponAmmoStock( w ) <= weaponClipSize( w ) )
			self giveMaxAmmo( w );
	}
}

// Thrown equipment comes back (+1) half a second later; C4 and killstreak markers don't.
an_equipment_refill()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "grenade_fire", grenade, weapon );
		if ( !isDefined( weapon ) || weapon == "satchel_charge_mp" )
			continue;
		if ( maps\mp\gametypes\_hardpoints::isKillstreakWeapon( weapon ) )
			continue;
		self thread an_equipment_give_back( weapon );
	}
}

an_equipment_give_back( weapon )
{
	self endon( "disconnect" );
	self endon( "death" );
	wait 0.5;
	if ( self hasWeapon( weapon ) )
		self setWeaponAmmoClip( weapon, self getWeaponAmmoClip( weapon ) + 1 );
	else
	{
		self giveWeapon( weapon );
		self setWeaponAmmoClip( weapon, 1 );
	}
}

// ---------------------------------------------------------------- canswap drop

// Weapon groups and guns come from the game's own table (stock _class builds
// level.tbl_weaponIDs from mp/statstable.csv: reference, group, attachment list).
an_drop_groups()
{
	return strTok( "weapon_assault weapon_smg weapon_lmg weapon_sniper weapon_cqb weapon_pistol weapon_launcher weapon_special", " " );
}

an_drop_group_name( group )
{
	switch ( group )
	{
		case "weapon_assault": return "Assault Rifles";
		case "weapon_smg": return "Submachine Guns";
		case "weapon_lmg": return "Light Machine Guns";
		case "weapon_sniper": return "Sniper Rifles";
		case "weapon_cqb": return "Shotguns";
		case "weapon_pistol": return "Pistols";
		case "weapon_launcher": return "Launchers";
		case "weapon_special": return "Specials";
	}
	return group;
}

an_drop_guns( group )
{
	guns = [];
	if ( !isDefined( level.tbl_weaponIDs ) )
		return guns;
	for ( i = 0; i < 256; i++ )
	{
		if ( !isDefined( level.tbl_weaponIDs[i] ) )
			continue;
		if ( level.tbl_weaponIDs[i]["group"] == group && level.tbl_weaponIDs[i]["reference"] != "" && level.tbl_weaponIDs[i]["reference"] != "weapon_null" )
			guns[ guns.size ] = level.tbl_weaponIDs[i]["reference"];
	}
	return guns;
}

an_drop_attachments( gun )
{
	for ( i = 0; i < 256; i++ )
		if ( isDefined( level.tbl_weaponIDs[i] ) && level.tbl_weaponIDs[i]["reference"] == gun )
			return strTok( level.tbl_weaponIDs[i]["attachment"], " " );
	return [];
}

an_attachment_name( a )
{
	switch ( a )
	{
		case "none": return "No Attachment";
		case "acog": return "ACOG Sight";
		case "elbit": return "Red Dot Sight";
		case "reflex": return "Reflex Sight";
		case "upgradesight": return "Upgraded Iron Sights";
		case "ir": return "Infrared Scope";
		case "vzoom": return "Variable Zoom";
		case "extclip": return "Extended Mag";
		case "dualclip": return "Dual Mag";
		case "silencer": return "Suppressor";
		case "gl": return "Grenade Launcher";
		case "mk": return "Masterkey";
		case "ft": return "Flamethrower";
		case "grip": return "Grip";
		case "rf": return "Rapid Fire";
		case "auto": return "Full Auto";
		case "dw": return "Dual Wield";
		case "snub": return "Snub Nose";
		case "speed": return "Speed Reloader";
	}
	return an_upper( a );
}

// Weapon name the stock way (_class getFullWeaponName): dual wield = gun + "dw_mp".
an_drop_weapon_name( gun, attachment )
{
	if ( attachment == "none" )
		return gun + "_mp";
	if ( attachment == "dw" )
		return gun + "dw_mp";
	return gun + "_" + attachment + "_mp";
}

an_drop_weapon( gun, attachment )
{
	if ( !isAlive( self ) )
		return;
	name = an_drop_weapon_name( gun, attachment );
	self giveWeapon( name );
	if ( !self hasWeapon( name ) )
	{
		self iPrintLn( "The game refused " + name );
		an_log( "drop refused " + name );
		return;
	}
	self dropItem( name );
	an_log( "canswap drop " + name + " by " + self.name );
}

// ---------------------------------------------------------------- grenade launcher ricochets

// Grenade launcher rounds (China Lake, underbarrel GL) get a bounce flag so the
// damage rules can tell a ricochet from a direct impact.
an_gl_fire_watch()
{
	self thread an_gl_fire_notify( "missile_fire" );
	self thread an_gl_fire_notify( "grenade_launcher_fire" );
}

an_gl_fire_notify( name )
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( name, projectile, weapon );
		if ( isDefined( projectile ) && isDefined( weapon ) && an_is_grenade_launcher( weapon ) )
			projectile thread an_gl_bounce_watch( self );
	}
}

an_gl_bounce_watch( owner )
{
	self endon( "death" );
	self waittill( "grenade_bounce" );
	self.an_bounced = true;
	owner.an_last_gl_bounce = getTime();
	an_log( "gl bounce " + owner.name );
}

an_is_grenade_launcher( weapon )
{
	// China Lake, and the underbarrel launcher's alt weapon "gl_<gun>_mp"
	return isSubStr( weapon, "china_lake" ) || ( weapon.size > 3 && getSubStr( weapon, 0, 3 ) == "gl_" );
}

// Upper case without relying on a builtin the stock T5 scripts never use.
an_upper( text )
{
	lower = "abcdefghijklmnopqrstuvwxyz";
	upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	out = "";
	for ( i = 0; i < text.size; i++ )
	{
		c = text[i];
		for ( j = 0; j < 26; j++ )
		{
			if ( c == lower[j] )
			{
				c = upper[j];
				break;
			}
		}
		out = out + c;
	}
	return out;
}

// ---------------------------------------------------------------- server plugin (anubis-weapons-t5)

// The server plugin registers an_weaponsPatched 1 when its patch is active.
an_weapons_plugin()
{
	return getdvar( "an_weaponsPatched" ) == "1";
}

// The plugin reads per client slot the weapon indices each setting covers:
// two per dvar (index + index2 * 65536), the "x" dvar holds two more (alternate
// modes such as the underbarrel grenade launcher are their own weapons).
an_plugin_sync()
{
	if ( !an_weapons_plugin() || self an_is_bot() )
		return;
	slot = self getEntityNumber();
	keys = strTok( "is:isw:isx ac:acw:acx nc:ncw:ncx fc:fcw:fcx", " " );
	for ( k = 0; k < keys.size; k++ )
	{
		t = strTok( keys[k], ":" );
		list = self an_plugin_indices( t[0] );
		self an_plugin_set( "an_" + t[1] + slot, list, 0 );
		self an_plugin_set( "an_" + t[2] + slot, list, 2 );
	}
}

an_plugin_indices( key )
{
	list = [];
	weapons = self getWeaponsList();
	for ( i = 0; i < weapons.size; i++ )
	{
		w = weapons[i];
		if ( w == "none" || w.size < 4 )
			continue;
		// the underbarrel launcher is its own weapon, "gl_<gun>_mp": it follows its gun's setting
		alt = getSubStr( w, 0, 3 ) == "gl_";
		gun = w;
		if ( alt )
			gun = getSubStr( w, 3 );
		if ( !self an_setting_applies( key, gun ) || ( !alt && !self an_is_primary( w ) ) )
			continue;
		idx = getWeaponIndexFromName( w );
		if ( isDefined( idx ) && idx > 0 && list.size < 4 )
			list[ list.size ] = idx;
	}
	return list;
}

an_plugin_set( name, list, from )
{
	v = 0;
	if ( list.size > from )
		v = list[ from ];
	if ( list.size > from + 1 )
		v = v + list[ from + 1 ] * 65536;
	if ( getdvar( name ) != "" + v )
	{
		setdvar( name, v );
		an_log( "plugin " + name + " = " + v + " (" + self.name + ")" );
	}
}

// Smooth action: the plugin forces the idle animation once per counter change.
an_smooth_action()
{
	if ( !an_weapons_plugin() )
	{
		self iPrintLn( "Smooth action only works on the Anubis server" );
		return;
	}
	d = "an_sm" + self getEntityNumber();
	setdvar( d, int( getdvar( d ) ) + 1 );
	an_log( "smooth " + self.name );
}
