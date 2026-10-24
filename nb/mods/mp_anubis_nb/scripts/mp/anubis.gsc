#include common_scripts\utility;
#include maps\mp\_utility;

// Anubis for Plutonium T5 multiplayer.
// Source is split for editing; tools/build.sh joins every file into one script.

main()
{
	an_rounds_main();
	an_edition_main();
}

init()
{
	level.an_build = an_build();
	// read over rcon by tools/deploy_t5.sh to confirm a map reload picked up a new build
	setdvar( "an_build", level.an_build );
	level.an_accent = ( 0.72, 0.09, 0.11 );
	level.an_strings = [];
	level.an_string_count = 0;

	precacheShader( "white" );

	an_movement_init();
	an_rounds_init();
	an_roles_init();
	level thread an_server_dvars();
	level thread an_bot_init();
	an_friendly_init();
	an_lunge_init();
	an_rapid_init();
	an_vote_init();
	an_edition_init();
	if ( getdvar( "g_gametype" ) == "sd" )
		level thread an_sui_watch();
	level thread an_on_connect();
	level thread an_class_attach_log();

	level.an_old_player_damage = level.callbackPlayerDamage;
	level.callbackPlayerDamage = ::an_player_damage;

	an_log( "init build " + level.an_build + " map " + getdvar( "mapname" ) + " gametype " + getdvar( "g_gametype" ) + " dedicated " + getdvar( "dedicated" ) + " onlinegame " + level.onlineGame );
}

an_build()
{
	return "88";
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
	self thread an_smooth_bind_watch();
	self thread an_stall_watch();
	self thread an_dpad_bind_watch();
	self thread an_edition_connected();
	self thread an_team_on_connect();
	self thread an_menu_close_on_death();
	self thread an_menu_close_on_end();
	self thread an_weapons_player();
	self thread an_class_change_watch();
	self thread an_late_spawn();
	self thread an_class_secondary_log();
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
	an_log( "plugin: weapons " + getdvar( "an_weaponsPatched" ) + ", wallbang " + getdvar( "bg_surfacePenetrationPatched" ) + ", ladder " + getdvar( "an_ladderFixPatched" ) + " (an_ladderFix " + getdvar( "an_ladderFix" ) + ")" + " (bg_surfacePenetration " + getdvar( "bg_surfacePenetration" ) + ")" );
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
	// The file copy opens / writes / closes a file for every line on the server
	// thread; a dedicated server already has every line in games_mp.log. Kill switch:
	// set an_log_file 1 (copy on the dedicated server too).
	if ( !isDefined( level.an_log_copy ) )
		level.an_log_copy = !an_is_dedicated() || getdvar( "an_log_file" ) == "1";
	if ( level.an_log_copy )
		level thread an_log_file( text );
}

// Copy of the log in scriptdata (private matches may have no games_mp.log).
an_log_file( text )
{
	file = fs_fopen( an_save_root() + "log.txt", "append" );
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
	if ( an_edition_maps() != "" )
		return strTok( an_edition_maps(), " " );
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
	return an_edition_map_name( map );
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
		// an_loop is NOT reset here: a loop kept on through a Maps-page change loops the
		// new map (Ankh 2026-10-19 "restart loop isnt working": live log 330:35, loop on
		// mp_cosmodrome, "cmd map mp_crisis" reset it and crisis ended with a vote)
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
		if ( level.players[i] an_is_bot() && !level.players[i] an_is_friendly_bot() )
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
	// friendly bots (friendly.gsc); a pending add means this connect is one of them
	if ( !self an_is_friendly_bot() && isDefined( level.an_friendly_pending ) )
		self.pers["an_friendly"] = level.an_friendly_pending;
	if ( self an_is_friendly_bot() )
	{
		self an_friendly_connected();
		return;
	}
	level.an_bot = self;
	if ( !isDefined( self.pers["team"] ) || ( self.pers["team"] != "allies" && self.pers["team"] != "axis" ) )
	{
		team = "axis";
		if ( isDefined( level.an_bot_team ) )
			team = level.an_bot_team;
		self thread maps\mp\gametypes\_bot::bot_spawn_think( team );
	}
	self.an_alive_seen = false;
	self.an_life_armed = false;
	self thread an_bot_hold();
	self thread an_bot_late_spawn();
	self thread an_bot_death_watch();
	self thread an_bot_kill_watch();
	self thread an_bot_class_keep();
	for ( ;; )
	{
		self waittill( "spawned_player" );
		self an_bot_spawned( "notify" );
	}
}

// Build 23 log (CONFIRMED): the bot's class is undefined or "" (stock bot_spawn_think
// sends changeclass "smg_mp", which level.classMap doesn't know, after every spawn).
// Stock updateTeamStatus only counts players with a class (_globallogic.gsc:1491), so
// the bot's team counted 0 and stock giveRankXP gave no kill XP / popup
// (_rank.gsc:406). A non-custom class still gets the bot loadout (_class.gsc:1756).
an_bot_class_keep()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		if ( !isDefined( self.class ) || self.class == "" || !isDefined( self.pers["class"] ) || self.pers["class"] == "" )
		{
			self.pers["class"] = level.defaultClass;
			self.class = level.defaultClass;
		}
		wait 0.05;
	}
}

// Build 14 log: the bot was alive in some rounds without "spawned_player" ever
// reaching this script, so the hold loop also runs this on every dead -> alive
// change. Once per life.
an_bot_spawned( how )
{
	if ( isDefined( self.an_life_armed ) && self.an_life_armed )
		return;
	self.an_life_armed = true;
	self.an_alive_seen = true;
	an_log( "bot spawned (" + how + "), setup " + getdvar( "an_bot_setup" ) );
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
		if ( isAlive( self ) && !( isDefined( self.an_life_armed ) && self.an_life_armed ) )
			self an_bot_spawned( "seen alive" );
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
	self endon( "death" );
	level endon( "game_ended" );
	for ( tries = 0; tries < 3; tries++ )
	{
		for ( i = 0; i < 100; i++ )
		{
			if ( self.an_alive_seen || isAlive( self ) )
				return;
			if ( isDefined( self.pers["team"] ) && ( self.pers["team"] == "allies" || self.pers["team"] == "axis" ) && isDefined( self.class ) && self.class != "" && game["state"] == "playing" && !level.inPrematchPeriod )
				break;
			wait 0.1;
		}
		wait 0.5;
		// a bot that was alive this round is never brought back (its death has to
		// end the round with the killcam)
		if ( self.an_alive_seen || isAlive( self ) )
			return;
		self.hasSpawned = true;
		if ( !isDefined( self.pers["lives"] ) || self.pers["lives"] < 1 )
			self.pers["lives"] = 1;
		waiting = isDefined( self.waitingToSpawn ) && self.waitingToSpawn;
		an_log( "bot late spawn try " + ( tries + 1 ) + " maySpawn " + an_bool( self maps\mp\gametypes\_globallogic_spawn::maySpawn() ) + " waiting " + an_bool( waiting ) + " session " + self.sessionstate );
		if ( waiting || tries > 0 )
		{
			// the stock wait never finished last time: spawn directly
			self.waitingToSpawn = false;
			self notify( "end_respawn" );
			self thread [[ level.spawnPlayer ]]();
		}
		else
			self thread maps\mp\gametypes\_globallogic_spawn::spawnClient();
		self waittill_any_timeout_an( 3, "spawned_player" );
		wait 0.05;
		if ( isAlive( self ) )
		{
			self an_bot_spawned( "late spawn" );
			return;
		}
	}
	an_log( "bot late spawn gave up" );
}

// Every life counts once: with a life left over, stock S&D counts the bot's team as
// still in the round and the round doesn't end on the kill (no killcam).
an_bot_death_watch()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "death" );
		self.an_life_armed = false;
		self.pers["lives"] = 0;
		an_log( "bot died, lives " + self.pers["lives"] );
	}
}

// Stock Callback_PlayerKilled sends "killed_player" after its own postgame check, so
// the kill is always processed (and its final killcam recorded) before the round ends.
an_bot_kill_watch()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "killed_player" );
		if ( isDefined( self.pers["team"] ) && ( self.pers["team"] == "allies" || self.pers["team"] == "axis" ) )
			level thread an_bot_death_round_check( self.pers["team"] );
	}
}

// Build 17 log: the bot (the only defender) died at 316100 and the round kept going
// (the auto plant fired 1.1 s later), so no killcam. The kill ends the round at once
// (Ankh): at the end of the death frame, if the bot's team has nobody alive, the dead
// event is sent here: same stock path (sd onDeadEvent -> round end). Stock
// Callback_PlayerKilled then sees game["state"] != "playing" ~2 s after the death and
// records/plays the final killcam of this kill (_globallogic_player.gsc:2038). The
// counters are logged to find out why stock didn't.
an_bot_death_round_check( team )
{
	level endon( "game_ended" );
	waittillframeend;
	if ( level.gameEnded || game["state"] != "playing" )
		return;
	for ( i = 0; i < level.players.size; i++ )
	{
		p = level.players[i];
		if ( isAlive( p ) && isDefined( p.pers["team"] ) && p.pers["team"] == team )
			return;
	}
	an_log( "bot team " + team + " wiped, round still on: alive " + level.aliveCount[ team ] + " lives " + level.playerLives[ team ] + " existed " + an_bool( level.everExisted[ team ] ) + " grace " + an_bool( level.inGracePeriod ) + " numLives " + level.numLives + " -> round ends now" );
	[[ level.onDeadEvent ]]( team );
}

// common_scripts has no waittill_any_timeout in T5
waittill_any_timeout_an( timeout, name )
{
	self endon( name );
	wait timeout;
}

// Class Editor (Ankh 2026-10-13): any gun in a custom class's secondary slot.
// Server-side setdstat on CacLoadouts is ignored by Plutonium T5 (read back unchanged in
// a private match and on the dedicated test server), so the player's own game writes it:
// ui_mp/anubis_class.menu (tools/gen_class_menu.py, in anubis_menu.iwd) runs
// statWriteDDL cacLoadouts customclassN secondary <statstable index>. Raw / IWD menus only
// load with ui_loadRawMenus 1 (cheat protected for the player; the server's setClientDvar
// works, build 37) → an_raw_menus_on on connect. Front end only (Ankh: in game and the
// bind abandoned): after joining an Anubis server once, in the mod's main menu console:
// openmenu anubis_class

// Same steps as the mid-life class change (rounds.gsc an_class_change_watch).
an_class_regive()
{
	self maps\mp\gametypes\_class::setClass( self.pers["class"] );
	self.tag_stowed_back = undefined;
	self.tag_stowed_hip = undefined;
	self maps\mp\gametypes\_class::giveLoadout( self.pers["team"], self.pers["class"] );
	self maps\mp\gametypes\_hardpoints::giveOwnedKillstreak();
	self an_perks_apply();
	self an_semtex_after_loadout();
	self an_speed_apply();
	self thread an_record_weapon_options();
}

// Front-end class menu (ui_mp/mod.txt + anubis_class.menu in anubis_menu.iwd) only loads
// with ui_loadRawMenus 1, which is cheat protected on the player's game ("Error:
// ui_loadRawMenus is cheat protected"). Plutonium staff (forum): setClientDvar from the
// server can set cheat-protected dvars that aren't saved ones; this one isn't saved.
// Test: does the player's game take it (value 1, no error in its console)?
an_raw_menus_on()
{
	self setClientDvar( "ui_loadRawMenus", "1" );
	an_log( "ui_loadRawMenus 1 sent to " + self.name );
}

// Attachment dropdowns (front-end class menu, tools/gen_class_menu.py) write
// secondaryattachment<point> <n>, n = the attachment's place in the gun's own list.
// Stock getFullWeaponName turns n back into a name with GetItemAttachment(gun, n); this logs
// that list for every gun once per server start so the menu's numbers can be checked.
an_class_attach_log()
{
	if ( getdvar( "an_att_logged" ) == "1" )
		return;
	setdvar( "an_att_logged", "1" );
	wait 1;
	if ( !isDefined( level.tbl_weaponIDs ) )
		return;
	keys = getArrayKeys( level.tbl_weaponIDs );
	for ( k = 0; k < keys.size; k++ )
	{
		i = keys[k];
		w = level.tbl_weaponIDs[i];
		if ( !isDefined( w["attachment"] ) || w["attachment"] == "" )
			continue;
		tokens = strTok( w["attachment"], " " );
		// 0 .. size-1 stays inside the list whether or not slot 0 is "none"
		line = "attach list " + w["reference"] + " (" + i + ") table [" + w["attachment"] + "] game";
		for ( n = 0; n < tokens.size; n++ )
			line = line + " " + n + "=" + getItemAttachment( i, n );
		an_log( line );
	}
}

// What the server builds from each custom class at the first spawn (stock cac_getdata ->
// getFullWeaponName), e.g. psg1_acog_mp when the dropdown picked ACOG for a PSG1 secondary.
an_class_secondary_log()
{
	self endon( "disconnect" );
	self waittill( "spawned_player" );
	if ( !isDefined( self.custom_class ) )
		return;
	line = "class secondaries " + self.name;
	keys = getArrayKeys( self.custom_class );
	for ( k = 0; k < keys.size; k++ )
	{
		c = self.custom_class[keys[k]];
		if ( isDefined( c ) && isDefined( c["secondary"] ) )
			line = line + " | " + keys[k] + " " + c["primary"] + " / " + c["secondary"];
	}
	an_log( line );
}

// Damage rules (Anubis, Ankh's T5 weapon list 2026-10-12):
// - humans only die to the map (falls out of the map, death triggers, crushes);
// - the bot never hurts anyone;
// - the bot dies in one hit to snipers, the FAL / M14, the ballistic knife (thrown), the tomahawk
//   and grenade launcher rounds that ricocheted first; any other hit only flinches
//   it, except knife hits, which do nothing.
// Plus almost hits and afterhit prone.

an_player_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset )
{
	attacker_is_player = isDefined( eAttacker ) && isPlayer( eAttacker );
	// friendly bots (friendly.gsc) are scenery: never hurt, never counted as a bot kill
	if ( self an_is_friendly_bot() )
		return;
	if ( !self an_is_bot() )
	{
		if ( attacker_is_player && eAttacker an_is_bot() )
			return;
		if ( !an_is_map_death( sMeansOfDeath, sWeapon ) )
			return;
		if ( self an_edition_skip_damage( eInflictor, eAttacker, sMeansOfDeath ) )
			return;
	}
	else if ( attacker_is_player && !eAttacker an_is_bot() )
	{
		// Build 14: a knife hit that left the bot alive crashed the attacker's game
		// (server log: "bot hit by Ankh knife_mp MOD_MELEE", then his client died).
		// Stock BO1 knives always kill, so a surviving knife victim never happens
		// there: knife hits on the bot are dropped.
		if ( sMeansOfDeath == "MOD_MELEE" )
		{
			an_log( "bot knifed by " + eAttacker.name + " (ignored)" );
			return;
		}
		eAttacker.an_last_hit_time = getTime();
		an_log( "bot hit by " + eAttacker.name + " " + sWeapon + " " + sMeansOfDeath );
		if ( an_is_killer( eAttacker, eInflictor, sWeapon, sMeansOfDeath ) )
		{
			// a killing hit must kill, not down the bot into last stand
			self an_bot_no_last_stand();
			iDamage = self.health + 1000;
			eAttacker thread an_on_bot_kill( self, sWeapon, maps\mp\gametypes\_globallogic_utils::isHeadShot( sWeapon, sHitLoc, sMeansOfDeath ) );
		}
		else
		{
			iDamage = 1;
			self thread an_restore_health();
		}
	}
	else if ( !an_is_map_death( sMeansOfDeath, sWeapon ) )
	{
		// Killstreaks hand in their own entity as the attacker (live log 2026-10-13:
		// the bot killed by cobra_20mm_comlink_mp, attack helicopter, with no "bot hit"
		// line), so they skipped the rules above. The bot only takes map deaths there.
		an_log( "bot damage ignored " + sWeapon + " " + sMeansOfDeath );
		return;
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

// Bullet guns that kill the bot (and count for almost hits): every sniper rifle and
// the semi-auto assault rifles, FN FAL and M14 (Ankh 2026-10-13). Underbarrel
// launchers ("gl_<gun>_mp") start with "gl" and are not these guns.
an_is_killer_gun( weapon )
{
	if ( maps\mp\gametypes\_missions::getWeaponClass( weapon ) == "weapon_sniper" )
		return true;
	base = strTok( weapon, "_" )[0];
	return base == "fnfal" || base == "m14";
}

an_is_killer( attacker, inflictor, weapon, mod )
{
	if ( !isDefined( weapon ) || weapon == "" || mod == "MOD_MELEE" )
		return false;
	if ( an_is_killer_gun( weapon ) )
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

an_on_bot_kill( bot, weapon, headshot )
{
	self endon( "disconnect" );
	// rounds.gsc an_on_end_game: a round the bomb ends still gets this kill's final killcam
	level.an_bot_human_kill = getTime();
	m = int( distance( self.origin, bot.origin ) * 0.0254 );
	an_log( "bot killed by " + self.name + " " + weapon + " " + m + "m" );
	// stock Long Shot medal rule (_medals.gsc:283-291): farther than the weapon's distance
	longshot = false;
	far = maps\mp\_medals::get_distance_for_weapon( weapon );
	if ( far > 0 && distanceSquared( bot.origin, self.origin ) > far * far )
		longshot = true;
	self thread an_xp_popup_check( headshot, longshot );
	if ( self.pers["an_afh"] == "stance" )
		self thread an_afterhit_prone( false );
	else if ( self.pers["an_afh"] == "instant" )
		self thread an_afterhit_prone( true );
	if ( self.pers["an_afr"] != "off" )
		self thread an_afterhit_reload( self.pers["an_afr"] );
}

// The reload animation depends on the clip when the reload starts (BO1
// bg_weapons.cpp PM_SetReloadingState): rounds left = normal reload, empty = empty
// mag reload.
// empty: the clip's rounds go to the reserve and the clip is set to 0; the engine
//   starts a reload by itself on an empty clip with reserve ammo (bg_weapons.cpp:2425).
// normal: the server plugin presses the reload button for this player (an_rl<slot>
//   counter); without the plugin (private match) it falls back to empty.
an_afterhit_reload( mode )
{
	self endon( "disconnect" );
	self endon( "death" );
	waittillframeend;
	w = self getCurrentWeapon();
	if ( w == "none" || w == "" || !self an_is_primary( w ) )
		return;
	clip = self getWeaponAmmoClip( w );
	if ( mode == "normal" && getdvar( "an_rl0" ) != "" && clip > 0 )
	{
		d = "an_rl" + self getEntityNumber();
		setdvar( d, int( getdvar( d ) ) + 1 );
		an_log( "afterhit reload normal " + self.name + " " + w + " clip " + clip );
		return;
	}
	if ( clip <= 0 )
		return;
	self setWeaponAmmoStock( w, self getWeaponAmmoStock( w ) + clip );
	self setWeaponAmmoClip( w, 0 );
	an_log( "afterhit reload empty " + self.name + " " + w + " clip " + clip + " (asked " + mode + ")" );
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

// Kill XP popup ("+500", headshot "+1000"): stock _rank::giveRankXP -> updateRankScoreHUD.
// Build 22 log: giveRankXP saw level.playerCount 1/0 (one team empty) and gave nothing
// (_rank.gsc:406 needs a player on both teams). If the kill gave no XP, give it again
// through giveRankXP's own devAdd argument, which skips that team check only.
// Every player's team / class / state is logged to find why one isn't counted.
an_xp_popup_check( headshot, longshot )
{
	self endon( "disconnect" );
	waittillframeend;
	wait 0.05;
	given = ( isDefined( self.rankUpdateTotal ) && self.rankUpdateTotal > 0 ) || ( isDefined( self.hud_rankscroreupdate ) && self.hud_rankscroreupdate.alpha > 0 );
	line = "xp popup " + self.name + " given " + an_bool( given ) + " headshot " + an_bool( headshot ) + " longshot " + an_bool( longshot );
	line = line + " count " + level.playerCount["allies"] + "/" + level.playerCount["axis"] + " state " + game["state"];
	for ( i = 0; i < level.players.size; i++ )
	{
		p = level.players[i];
		c = "undefined";
		if ( isDefined( p.class ) )
			c = "[" + p.class + "]";
		line = line + " | " + p.name + " team " + p.team + " class " + c + " session " + p.sessionstate;
	}
	an_log( line );
	if ( given || !isDefined( level.rankEnabled ) || !level.rankEnabled )
		return;
	self thread maps\mp\gametypes\_rank::giveRankXP( "kill", undefined, true );
	if ( headshot )
		self thread maps\mp\gametypes\_rank::giveRankXP( "headshot", undefined, true );
	// Long Shot medal: 50 XP (medaltable.csv row 2), "+550" with the kill
	if ( longshot )
	{
		xp = 50;
		if ( isDefined( level.medalInfo ) && isDefined( level.medalInfo["MEDAL_LONG_SHOT"] ) )
			xp = level.medalInfo["MEDAL_LONG_SHOT"]["xp"].team;
		self thread maps\mp\gametypes\_rank::giveRankXP( "medal", xp, true );
	}
}

// Kill popup (Ankh 2026-10-13): only kill / headshot / long shot count, total shown at
// most +1000 (body +500, long shot +550, headshot +1000, headshot long shot +1000).
// Stock giveMedal (_medals.gsc:108) with one change: medals other than Long Shot still give
// their XP and medal splash, but giveRankXP runs with enableText off, so stock skips
// updateRankScoreHUD for them (_rank.gsc giveRankXP has no wait, the flag is back at once).
an_give_medal( medalName, weapon )
{
	self endon( "disconnect" );
	if ( !level.medalsEnabled )
		return;
	if ( level.wagerMatch && getDvar( "g_gametype" ) != "cp" )
		return;
	if ( self is_bot() )
		return;
	waittillframeend;
	if ( !isDefined( level.medalInfo[medalName] ) )
		return;
	if ( level.teambased )
		xp = level.medalInfo[medalName]["xp"].team;
	else
		xp = level.medalInfo[medalName]["xp"].player;
	if ( !level.wagerMatch && level.onlineGame && ( !getDvarInt( "xblive_privatematch" ) || getDvarInt( "xblive_basictraining" ) ) )
	{
		if ( medalName == "MEDAL_LONG_SHOT" )
		{
			self thread maps\mp\gametypes\_rank::giveRankXP( "medal", xp );
		}
		else
		{
			text = self.enableText;
			self.enableText = false;
			self maps\mp\gametypes\_rank::giveRankXP( "medal", xp );
			self.enableText = text;
		}
		self maps\mp\gametypes\_persistence::statAdd( "MEDALS", 1, false );
	}
	[[level.onMedalAwarded]]( self, medalName, xp );
	self thread maps\mp\_properks::medalEarned( medalName, weapon );
	if ( level.hardcoreMode == false || level.medalInfo[medalName]["hardcore"] == 1 )
		self maps\mp\_medals::addMedalToQueue( level.medalInfo[medalName]["index"] );
}

// Stock updateRankScoreHUD (_rank.gsc:689) with the popup capped at 1000. A single amount
// above 1000 (the end-of-match bonus) is shown in full.
an_rank_score_hud( amount )
{
	self endon( "disconnect" );
	self endon( "joined_team" );
	self endon( "joined_spectators" );
	if ( amount == 0 )
		return;
	self notify( "update_score" );
	self endon( "update_score" );
	self.rankUpdateTotal += amount;
	if ( amount > 1000 )
		self.an_xp_big = true;
	wait 0.05;
	if ( isDefined( self.hud_rankscroreupdate ) )
	{
		shown = self.rankUpdateTotal;
		if ( shown > 1000 && !( isDefined( self.an_xp_big ) && self.an_xp_big ) )
			shown = 1000;
		if ( shown < 0 )
		{
			self.hud_rankscroreupdate.label = &"";
			self.hud_rankscroreupdate.color = ( 0.73, 0.19, 0.19 );
		}
		else
		{
			self.hud_rankscroreupdate.label = &"MP_PLUS";
			self.hud_rankscroreupdate.color = ( 1, 1, 0.5 );
		}
		self.hud_rankscroreupdate setValue( shown );
		self.hud_rankscroreupdate.alpha = 0.85;
		self.hud_rankscroreupdate thread maps\mp\gametypes\_hud::fontPulse( self );
		wait 1;
		self.hud_rankscroreupdate fadeOverTime( 0.75 );
		self.hud_rankscroreupdate.alpha = 0;
		self.rankUpdateTotal = 0;
		self.an_xp_big = false;
	}
}

// ---------------------------------------------------------------- almost hits

// Sniper / FAL / M14 shot whose crosshair impact lands within 45 units of the bot's feet,
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
		if ( weapon == "none" || weapon == "" || self.pers["an_ah"] != "1" || !an_is_killer_gun( weapon ) )
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
	off = int( distance( impact, feet ) );
	if ( off > 45 )
	{
		an_log( "shot miss " + self.name + " landed " + off + " units from the bot's feet" );
		return;
	}
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
	self an_bot_no_last_stand();
}

// Second Chance (Pro = specialty_finalstand) put the bot into last stand on the
// killing shot, so it never died and the round never ended with the killcam
// (Ankh, build 15).
an_bot_no_last_stand()
{
	if ( self hasPerk( "specialty_pistoldeath" ) )
		self unsetPerk( "specialty_pistoldeath" );
	if ( self hasPerk( "specialty_finalstand" ) )
		self unsetPerk( "specialty_finalstand" );
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

an_afterhit_reload_cycle()
{
	switch ( self.pers["an_afr"] )
	{
		case "off": self.pers["an_afr"] = "empty"; break;
		case "empty": self.pers["an_afr"] = "normal"; break;
		default: self.pers["an_afr"] = "off"; break;
	}
}

an_almost_hit_toggle()
{
	if ( self.pers["an_ah"] == "1" )
		self.pers["an_ah"] = "0";
	else
		self.pers["an_ah"] = "1";
}

// Dpad binds for the edition's bindable commands (No Barriers: unstuck, resetspawn,
// enemyspawn). Each one: OFF / DPAD UP / DOWN / LEFT / RIGHT, pers an_db_<name>,
// saved with the personal settings. Dpad up only counts without aiming (aim + up opens
// the menu); nothing fires while the menu is open.

an_dpad_bind_watch()
{
	self endon( "disconnect" );
	names = strTok( an_edition_binds(), " " );
	if ( names.size == 0 )
		return;
	for ( i = 0; i < names.size; i++ )
		if ( !isDefined( self.pers[ "an_db_" + names[i] ] ) )
			self.pers[ "an_db_" + names[i] ] = "off";
	for ( ;; )
	{
		cmd = self waittill_any_return( "an_up", "an_down", "an_dpad_left", "an_dpad_right" );
		if ( self.an_menu_open )
			continue;
		switch ( cmd )
		{
			case "an_up":
				if ( self adsButtonPressed() )
					continue;
				key = "up";
				break;
			case "an_down": key = "down"; break;
			case "an_dpad_left": key = "left"; break;
			default: key = "right"; break;
		}
		for ( i = 0; i < names.size; i++ )
		{
			if ( self.pers[ "an_db_" + names[i] ] == key )
			{
				an_log( "dpad bind " + names[i] + " by " + self.name );
				self an_edition_bind( names[i] );
				break;
			}
		}
	}
}

an_dpad_bind_cycle( name )
{
	list = strTok( "off up down left right", " " );
	cur = self.pers[ "an_db_" + name ];
	next = list[0];
	for ( i = 0; i < list.size; i++ )
		if ( list[i] == cur && i + 1 < list.size )
			next = list[ i + 1 ];
	self.pers[ "an_db_" + name ] = next;
}

an_dpad_bind_text( name )
{
	v = self.pers[ "an_db_" + name ];
	if ( !isDefined( v ) || v == "off" )
		return "OFF";
	return "DPAD " + an_upper( v );
}

// Personal save keys: db_<name> for each edition bind.
an_dpad_bind_keys()
{
	keys = [];
	names = strTok( an_edition_binds(), " " );
	for ( i = 0; i < names.size; i++ )
		keys[ keys.size ] = "db_" + names[i];
	return keys;
}

// No Barriers edition (mods/mp_anubis_nb): replaces mod/src/edition.gsc.
// Own saves (scriptdata/anubis_nb), the patched maps only, and three binds:
//   bind <key> unstuck        straight up 150 units
//   bind <key> resetspawn     to a start spawn of your own side
//   bind <key> enemyspawn     to a start spawn of the other side


an_edition()
{
	return "nb";
}

an_save_root()
{
	return "anubis_nb/";
}

// Same list as tools/nbmap/maps.txt (Ankh's working maps 2026-10-23 + Nuketown).
an_edition_maps()
{
	return "mp_anubis_nuked mp_anubis_cosmodrome mp_anubis_crisis mp_anubis_cairo mp_anubis_firingrange mp_anubis_duga mp_anubis_russianbase mp_anubis_villa mp_anubis_hanoi mp_anubis_radiation mp_anubis_stadium mp_anubis_hotel mp_anubis_zoo mp_anubis_silo mp_anubis_area51 mp_anubis_berlinwall2";
}

an_edition_map_name( map )
{
	switch ( map )
	{
		case "mp_anubis_nuked": return "Nuketown";
		case "mp_anubis_cosmodrome": return "Launch";
		case "mp_anubis_crisis": return "Crisis";
		case "mp_anubis_cairo": return "Havana";
		case "mp_anubis_firingrange": return "Firing Range";
		case "mp_anubis_duga": return "Grid";
		case "mp_anubis_russianbase": return "WMD";
		case "mp_anubis_villa": return "Villa";
		case "mp_anubis_hanoi": return "Hanoi";
		case "mp_anubis_radiation": return "Radiation";
		case "mp_anubis_stadium": return "Stadium";
		case "mp_anubis_hotel": return "Hotel";
		case "mp_anubis_zoo": return "Zoo";
		case "mp_anubis_silo": return "Silo";
		case "mp_anubis_area51": return "Hangar 18";
		case "mp_anubis_berlinwall2": return "Berlin Wall";
	}
	return map;
}

an_edition_binds()
{
	return "unstuck resetspawn enemyspawn";
}

// Renamed maps have no row in mp/mapsTable.csv (code_post_gfx_mp), which stock
// _teams::setPlayerModels reads by mapname for the team sets; without one it falls back
// to junglemarines (SOG / NVA), whose models aren't in the map zone ("Could not load
// xmodel c_usa_sog_mp_body_*"): every player had no body (invisible, Ankh 2026-10-23).
// Same function, looked up under the stock map name (mp_anubis_nuked -> mp_nuked).
an_edition_main()
{
	replaceFunc( maps\mp\gametypes\_teams::setPlayerModels, ::an_nb_set_player_models );
}

an_nb_stock_map( map )
{
	prefix = "mp_anubis_";
	if ( map.size > prefix.size && getSubStr( map, 0, prefix.size ) == prefix )
		return "mp_" + getSubStr( map, prefix.size, map.size );
	return map;
}

an_nb_set_player_models()
{
	game["allies_model"] = [];
	map = an_nb_stock_map( getdvar( "mapname" ) );

	alliesCharSet = tableLookup( "mp/mapsTable.csv", 0, map, 1 );
	if ( !isDefined( alliesCharSet ) || alliesCharSet == "" || !isDefined( game["allies_teamset"][alliesCharSet] ) )
	{
		game["allies_soldiertype"] = "junglemarines";
		game["allies"] = "marines";
		alliesCharSet = "junglemarines";
	}
	else
		game["allies_soldiertype"] = alliesCharSet;

	axisCharSet = tableLookup( "mp/mapsTable.csv", 0, map, 2 );
	if ( !isDefined( axisCharSet ) || axisCharSet == "" || !isDefined( game["allies_teamset"][axisCharSet] ) )
	{
		game["axis_soldiertype"] = "junglemarines";
		game["axis"] = "nva";
		axisCharSet = "junglemarines";
	}
	else
		game["axis_soldiertype"] = axisCharSet;

	an_log( "nb team sets for " + map + ": " + game["allies_soldiertype"] + " / " + game["axis_soldiertype"] );
	[[ game["allies_teamset"][ game["allies_soldiertype"] ] ]]();
	[[ game["axis_teamset"][ game["axis_soldiertype"] ] ]]();
}

// Elevators (Ankh 2026-10-23 "actual elevators do not work"): BO1 player movement
// uses its new GJK collision when phys_player_collision_mode is 1 (default); the
// stuck correction that lifts a player out of a corner (PM_CorrectAllSolid) only
// runs with the older box traces, mode 0 (KisakBlack bg_pmove.cpp PM_GroundTrace).
// The dvar has no flags (t5mp.exe 0x541E6F: int 1, 0..1, flags 0), so the server and
// every player's game each keep their own copy: both are set, else prediction differs.
// Kill switch: set an_nb_elevators 0 (next map / reconnect).
an_edition_init()
{
	if ( getdvar( "an_nb_elevators" ) == "" )
		setdvar( "an_nb_elevators", "1" );
	mode = "1";
	if ( getdvar( "an_nb_elevators" ) != "0" )
		mode = "0";
	setdvar( "phys_player_collision_mode", mode );
	an_log( "nb elevators " + getdvar( "an_nb_elevators" ) + ": server phys_player_collision_mode=[" + getdvar( "phys_player_collision_mode" ) + "]" );
}

an_edition_connected()
{
	if ( self an_is_bot() )
		return;
	self setClientDvar( "phys_player_collision_mode", getdvar( "phys_player_collision_mode" ) );
}

an_edition_bind_rows( rows )
{
	rows[ rows.size ] = an_row( "bindinfo", "Unstuck", "unstuck" );
	rows[ rows.size ] = an_row( "dpadbind", "Unstuck Bind", "unstuck" );
	rows[ rows.size ] = an_row( "bindinfo", "Reset to Spawn", "resetspawn" );
	rows[ rows.size ] = an_row( "dpadbind", "Reset to Spawn Bind", "resetspawn" );
	rows[ rows.size ] = an_row( "bindinfo", "Reset to Enemy Spawn", "enemyspawn" );
	rows[ rows.size ] = an_row( "dpadbind", "Enemy Spawn Bind", "enemyspawn" );
	return rows;
}

// Out of the map: only the death triggers below the map centre (falling out of the
// world; movement.gsc an_barrier_init marks them with an_origin) still hurt. Sky and
// out-of-map volumes (Nuketown *111, script_noteworthy "tvguided_safe", dmg 1000 every
// frame = constant hurt flash, Ankh 2026-10-23) are ignored.
an_edition_skip_damage( eInflictor, eAttacker, mod )
{
	if ( mod != "MOD_TRIGGER_HURT" )
		return false;
	self thread an_nb_damage_probe( mod );
	t = eInflictor;
	if ( !isDefined( t ) || !isDefined( t.classname ) || t.classname != "trigger_hurt" )
		t = eAttacker;
	if ( !isDefined( t ) || !isDefined( t.classname ) || t.classname != "trigger_hurt" )
		return false;
	if ( isDefined( t.an_origin ) )
		return false;
	if ( !isDefined( self.an_nb_sky_logged ) )
	{
		self.an_nb_sky_logged = true;
		an_log( "nb: out-of-map trigger ignored for " + self.name + " at " + self.origin );
	}
	return true;
}

an_edition_bind( name )
{
	if ( level.gameEnded || !isAlive( self ) || self.sessionstate != "playing" || self.an_menu_open || isDefined( self.an_zip_busy ) )
		return;
	if ( isDefined( self.an_nb_move_time ) && getTime() - self.an_nb_move_time < 1000 )
		return;
	if ( isDefined( self.an_stalled ) )
		self an_stall_release();

	switch ( name )
	{
		case "unstuck":
			self.an_nb_move_time = getTime();
			self setOrigin( self.origin + ( 0, 0, 150 ) );
			an_log( "unstuck " + self.name + " to " + self.origin );
			break;
		case "resetspawn":
			self an_nb_to_spawn( false );
			break;
		case "enemyspawn":
			self an_nb_to_spawn( true );
			break;
	}
}

// S&D start spawns per side (stock sd.gsc onStartGameType); other modes use the
// team start spawns.
an_nb_to_spawn( enemy )
{
	team = self.pers["team"];
	if ( !isDefined( team ) || ( team != "allies" && team != "axis" ) )
		return;
	if ( enemy )
		team = getOtherTeam( team );

	if ( level.gameType == "sd" )
	{
		if ( team == game["attackers"] )
			classname = "mp_sd_spawn_attacker";
		else
			classname = "mp_sd_spawn_defender";
	}
	else
		classname = "mp_tdm_spawn_" + team + "_start";

	spots = maps\mp\gametypes\_spawnlogic::getSpawnpointArray( classname );
	if ( spots.size == 0 )
	{
		self iPrintLn( "No spawn points here" );
		an_log( "spawn bind: no " + classname + " for " + self.name );
		return;
	}
	spot = spots[ randomInt( spots.size ) ];
	self.an_nb_move_time = getTime();
	self setOrigin( spot.origin );
	self setPlayerAngles( spot.angles );
	self setVelocity( ( 0, 0, 0 ) );
	if ( enemy )
		an_log( "enemy spawn " + self.name + " to " + spot.origin + " (" + classname + ")" );
	else
		an_log( "reset spawn " + self.name + " to " + spot.origin + " (" + classname + ")" );
}

// Build 85 diagnostic (Ankh: falling off the map doesn't kill; nobody ever died on
// the NB server): health around a map damage hit, at most once every 2 s.
an_nb_damage_probe( mod )
{
	self endon( "disconnect" );
	if ( isDefined( self.an_nb_probe_time ) && getTime() - self.an_nb_probe_time < 2000 )
		return;
	self.an_nb_probe_time = getTime();
	before = self.health;
	waittillframeend;
	td = "?";
	if ( isDefined( self.takedamage ) )
		td = self.takedamage;
	an_log( "nb damage probe " + self.name + " " + mod + " health " + before + " -> " + self.health + " max " + self.maxhealth + " takedamage " + td + " alive " + isAlive( self ) + " state " + self.sessionstate + " at " + self.origin );
}

// Friendly bots (Ankh 2026-10-19: "friendly bots on toggle that spawn in random parts of
// the map so it looks like theres more players"). Manager -> Friendly Bots: OFF / 2 / 4 / 6
// (host dvar an_fb, kept across maps). They join the humans' team, stand frozen at a
// random spawn point away from everyone, never hurt anyone and can't be hurt. Each one
// carries a sniper and a pistol and fires one of them every few seconds (Ankh
// 2026-10-19: "periodically shoot their pistol and their sniper").
// Marked with pers["an_friendly"] (kept through S&D round restarts); the engine drops
// every bot on a map change (live log 2026-10-19: "bot added ... by auto" after each new
// map), so a friendly bot never comes back unmarked. an_bot_get() skips them, so they are
// never "the bot".

an_friendly_init()
{
	if ( getdvar( "an_fb" ) == "" )
		setdvar( "an_fb", "0" );
	level thread an_friendly_loop();
}

an_is_friendly_bot()
{
	return isDefined( self.pers ) && isDefined( self.pers["an_friendly"] );
}

an_friendly_list()
{
	list = [];
	for ( i = 0; i < level.players.size; i++ )
		if ( level.players[i] an_is_friendly_bot() )
			list[ list.size ] = level.players[i];
	return list;
}

// One bot added or kicked per pass (each add is a full client connect).
an_friendly_loop()
{
	level endon( "game_ended" );
	wait 5;
	for ( ;; )
	{
		wait 2;
		want = int( getdvar( "an_fb" ) );
		have = an_friendly_list();
		if ( have.size > want )
		{
			bot = have[ have.size - 1 ];
			an_log( "friendly bot kicked " + bot.name + " (" + have.size + " > " + want + ")" );
			kick( bot getEntityNumber() );
			continue;
		}
		if ( have.size == want )
			continue;
		team = an_human_team();
		if ( !isDefined( team ) )
			continue;
		// keep two slots free for people joining
		if ( level.players.size >= int( getdvar( "sv_maxclients" ) ) - 2 )
			continue;
		an_friendly_add( team );
	}
}

an_friendly_add( team )
{
	// an_bot_connected can run inside addTestClient (connect callback), before the mark
	// below is set: it reads this instead
	level.an_friendly_pending = team;
	bot = addTestClient();
	level.an_friendly_pending = undefined;
	if ( !isDefined( bot ) )
	{
		an_log( "friendly bot add failed (server full?)" );
		return;
	}
	bot.pers["isBot"] = true;
	bot.pers["an_friendly"] = team;
	an_log( "friendly bot added team " + team );
}

// From an_bot_connected for friendly bots (each connect, including round restarts).
an_friendly_connected()
{
	self endon( "disconnect" );
	if ( !isDefined( self.pers["team"] ) || ( self.pers["team"] != "allies" && self.pers["team"] != "axis" ) )
		self thread maps\mp\gametypes\_bot::bot_spawn_think( self.pers["an_friendly"] );
	self thread an_friendly_class_keep();
	self.an_fb_placed = false;
	for ( ;; )
	{
		// stock auto-assign / CanJoinTeam put one on the enemy team (Ankh's screenshot,
		// build 75): move it back
		if ( isDefined( self.pers["team"] ) && ( self.pers["team"] == "allies" || self.pers["team"] == "axis" ) && self.pers["team"] != self.pers["an_friendly"] )
			self an_friendly_set_team( self.pers["an_friendly"] );
		if ( isAlive( self ) )
		{
			if ( !self.an_fb_placed )
			{
				self.an_fb_placed = true;
				// a life that ended mid-shot left this set
				self.an_fb_firing = false;
				self an_friendly_place();
				self thread an_friendly_shoot();
			}
			// the round start unfreezes everyone (not while a shot is being fired)
			if ( !( isDefined( self.an_fb_firing ) && self.an_fb_firing ) )
				self freezeControls( true );
		}
		else
			self.an_fb_placed = false;
		wait 0.5;
	}
}

// Same reason as an_bot_class_keep (stock bot_spawn_think sends an unknown class after
// each spawn), at a slower rate: these bots are only counted, never killed.
an_friendly_class_keep()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		if ( !isDefined( self.class ) || self.class == "" || !isDefined( self.pers["class"] ) || self.pers["class"] == "" )
		{
			self.pers["class"] = level.defaultClass;
			self.class = level.defaultClass;
		}
		wait 0.25;
	}
}

// Random free-for-all spawn point (spread over the whole map), at least 500 units from
// every other live player; any spawn point after 20 tries.
an_friendly_place()
{
	spots = getEntArray( "mp_dm_spawn", "classname" );
	if ( spots.size == 0 )
		spots = getEntArray( "mp_tdm_spawn", "classname" );
	if ( spots.size == 0 )
	{
		an_log( "friendly bot " + self.name + ": no spawn points on this map" );
		return;
	}
	spot = spots[ randomInt( spots.size ) ];
	for ( tries = 0; tries < 20; tries++ )
	{
		spot = spots[ randomInt( spots.size ) ];
		if ( an_friendly_spot_free( spot.origin ) )
			break;
	}
	self setOrigin( spot.origin );
	self setPlayerAngles( spot.angles );
	an_log( "friendly bot " + self.name + " placed at " + spot.origin + " (try " + tries + ")" );
}

an_friendly_spot_free( origin )
{
	for ( i = 0; i < level.players.size; i++ )
	{
		p = level.players[i];
		if ( p == self || !isAlive( p ) )
			continue;
		if ( distanceSquared( p.origin, origin ) < 500 * 500 )
			return false;
	}
	return true;
}

an_friendly_cycle()
{
	steps = strTok( "0 2 4 6", " " );
	v = getdvar( "an_fb" );
	next = steps[0];
	for ( i = 0; i < steps.size; i++ )
		if ( steps[i] == v && i + 1 < steps.size )
			next = steps[ i + 1 ];
	setdvar( "an_fb", next );
	an_log( "friendly bots = " + next );
}

an_friendly_text()
{
	v = getdvar( "an_fb" );
	if ( v == "" || v == "0" )
		return "OFF";
	return v;
}

// One random sniper + one random pistol per life (stock statstable names; every class
// can carry them, so they're loaded on every map). Then random player-like activity
// (Ankh 2026-10-19: "it should be at random to simulate other players"): each bot gets
// its own activity level per life; gaps are mostly 3-15 s, sometimes a 15-40 s quiet
// spell, sometimes a quick follow-up; actions are a sniper shot (sometimes two), a
// pistol burst of 1-4, looking around, a weapon swap without firing, or a stance change.
// A frozen player can't fire: the bot is unfrozen with move speed 0 for the shots only
// (stock bots fire with PressAttackButton, _bot.gsc:2525). Their bullets do nothing to
// anyone (damage.gsc ignores bot attackers).
an_friendly_shoot()
{
	self endon( "disconnect" );
	self endon( "death" );
	self notify( "an_fb_shoot" );
	self endon( "an_fb_shoot" );
	wait 0.2;
	snipers = strTok( "l96a1_mp psg1_mp wa2000_mp dragunov_mp", " " );
	pistols = strTok( "m1911_mp cz75_mp makarov_mp python_mp asp_mp", " " );
	sniper = snipers[ randomInt( snipers.size ) ];
	pistol = pistols[ randomInt( pistols.size ) ];
	self takeAllWeapons();
	self giveWeapon( sniper );
	self giveWeapon( pistol );
	self giveMaxAmmo( sniper );
	self giveMaxAmmo( pistol );
	self switchToWeapon( sniper );
	self setMoveSpeedScale( 0 );
	self.an_fb_yaw = self getPlayerAngles()[1];
	// lower = busier
	activity = randomFloatRange( 0.5, 1.6 );
	// not all bots in step at the round start
	wait randomFloat( 6 );
	for ( ;; )
	{
		roll = randomInt( 100 );
		if ( roll < 10 )
			gap = randomFloatRange( 0.8, 2.5 );
		else if ( roll < 30 )
			gap = randomFloatRange( 15, 40 );
		else
			gap = randomFloatRange( 3, 15 );
		wait gap * activity;
		if ( level.gameEnded || ( isDefined( level.inPrematchPeriod ) && level.inPrematchPeriod ) )
			continue;
		roll = randomInt( 100 );
		if ( roll < 55 )
		{
			shots = 1;
			if ( randomInt( 100 ) < 20 )
				shots = 2;
			self an_friendly_look();
			self an_friendly_fire( sniper, shots, 1.1, 1.6 );
		}
		else if ( roll < 80 )
		{
			self an_friendly_look();
			self an_friendly_fire( pistol, 1 + randomInt( 4 ), 0.2, 0.6 );
		}
		else if ( roll < 90 )
			self an_friendly_look();
		else if ( roll < 95 )
		{
			if ( self getCurrentWeapon() == sniper )
				self switchToWeapon( pistol );
			else
				self switchToWeapon( sniper );
		}
		else
		{
			stances = strTok( "stand crouch prone", " " );
			self setStance( stances[ randomInt( stances.size ) ] );
		}
	}
}

// Turn: usually a drift from the last direction, sometimes anywhere.
an_friendly_look()
{
	if ( randomInt( 100 ) < 30 )
		self.an_fb_yaw = randomFloat( 360 );
	else
		self.an_fb_yaw = self.an_fb_yaw + randomFloatRange( -60, 60 );
	self setPlayerAngles( ( randomFloatRange( -10, 8 ), self.an_fb_yaw, 0 ) );
}

// shots presses, min_gap..max_gap s apart (sniper: rechamber time).
an_friendly_fire( w, shots, min_gap, max_gap )
{
	if ( self getCurrentWeapon() != w )
	{
		self switchToWeapon( w );
		for ( i = 0; i < 40 && self getCurrentWeapon() != w; i++ )
			wait 0.05;
		// let the raise finish
		wait 0.6;
	}
	self.an_fb_firing = true;
	self setMoveSpeedScale( 0 );
	self freezeControls( false );
	wait 0.05;
	for ( i = 0; i < shots; i++ )
	{
		if ( i > 0 )
			wait randomFloatRange( min_gap, max_gap );
		self PressAttackButton();
	}
	wait 0.25;
	self freezeControls( true );
	self.an_fb_firing = false;
	if ( self getWeaponAmmoStock( w ) < weaponClipSize( w ) )
		self giveMaxAmmo( w );
}

// Stock menuAllies / menuAxis (_globallogic_ui.gsc:497) without its CanJoinTeam check.
// Build 75 live (CONFIRMED, Ankh's scoreboard + log "friendly bot added team allies" for
// Khonsu): on connect stock auto-assign (_globallogic_player.gsc:393, ranked) balanced the
// bot onto axis, and the later switch to allies was refused by CanJoinTeam (allies would
// have had more players).
an_friendly_set_team( team )
{
	if ( isDefined( self.pers["team"] ) && self.pers["team"] == team )
		return;
	an_log( "friendly bot " + self.name + " team " + self.pers["team"] + " -> " + team );
	if ( self.sessionstate == "playing" )
	{
		self.switching_teams = true;
		self.joining_team = team;
		self.leaving_team = self.pers["team"];
		self suicide();
	}
	self.pers["team"] = team;
	self.team = team;
	self.sessionteam = team;
	self.pers["class"] = undefined;
	self.class = undefined;
	self.pers["weapon"] = undefined;
	self.pers["savedmodel"] = undefined;
	self notify( "joined_team" );
	level notify( "joined_team" );
	self notify( "end_respawn" );
	self maps\mp\gametypes\_globallogic_ui::beginClassChoice();
}

// Knife lunge (Ankh 2026-10-19: IW4x perk_extendedMeleeRange 9999 style; research in NOTES
// "knife lunge / IW4x perk_extendedMeleeRange"). Manager -> Knife Lunge, host dvar an_lunge:
//   off    - stock: a lunge only starts at a target 64-90 units away with a gun out
//            (player_meleeRange 64 < distance <= aim_automelee_range 90; a gun's own
//            meleeChargeRange is 0, so the dvar is used; the knife's weapon file has 128);
//   far    - lunge at a target up to 255 units away: aim_automelee_range 255 on the player's
//            game (registered max 255; the lunge distance is one byte in the usercmd, so no
//            further is possible; stock default 90);
//   always - every knife press from the ground lunges 250 units forward with no target:
//            player_bayonetLaunchDebugging 1 (PM_MeleeChargeStart, bg_pmove.cpp:1497). The
//            server runs the same movement code, so it is set on the server AND every
//            player's game (one side only = rubber-banding).
// Both are cheat dvars: the server's own setDvar of cheat dvars works (live dvars line:
// jump_slowdownEnable=[0]), and setClientDvar reaches the player's game (ui_loadRawMenus,
// classes.gsc). Knife hits on the bot still do nothing (build 15 crash fix).

an_lunge_init()
{
	// FAR by default (Ankh 2026-10-20 "knife lunges still dont work": the toggle was never
	// switched on, and stock only lunges at a target 64-90 units away). One-time switch
	// for servers that already stored "off" (an_lunge_v).
	if ( getdvar( "an_lunge" ) == "" || getdvar( "an_lunge_v" ) != "2" )
	{
		setdvar( "an_lunge", "far" );
		setdvar( "an_lunge_v", "2" );
	}
	an_lunge_apply_server();
}

an_lunge_apply_server()
{
	v = "0";
	if ( getdvar( "an_lunge" ) == "always" )
		v = "1";
	setdvar( "player_bayonetLaunchDebugging", v );
	an_log( "knife lunge " + getdvar( "an_lunge" ) + ": server player_bayonetLaunchDebugging=[" + getdvar( "player_bayonetLaunchDebugging" ) + "]" );
}

// On every human spawn and for everyone when the setting changes.
an_lunge_apply_player()
{
	mode = getdvar( "an_lunge" );
	range = "90";
	if ( mode == "far" )
		range = "255";
	debug = "0";
	if ( mode == "always" )
		debug = "1";
	self setClientDvar( "aim_automelee_range", range );
	self setClientDvar( "player_bayonetLaunchDebugging", debug );
}

an_lunge_cycle()
{
	switch ( getdvar( "an_lunge" ) )
	{
		case "far": next = "always"; break;
		case "always": next = "off"; break;
		default: next = "far"; break;
	}
	setdvar( "an_lunge", next );
	an_lunge_apply_server();
	for ( i = 0; i < level.players.size; i++ )
		if ( an_is_human( level.players[i] ) )
			level.players[i] an_lunge_apply_player();
}

an_lunge_text()
{
	v = getdvar( "an_lunge" );
	if ( v == "" )
		return "OFF";
	return an_upper( v );
}

// Menu: script-drawn hud elements (T5 has no LUI; see NOTES.md section 5).
// Layout and colours follow the approved Anubis look (spine + card, black /
// grey / dark red), scaled to the 640x480 hud space.
// Budget: T5 sends 31 "current" (archived = false) + 31 "archived" hud elems per
// player and silently drops the rest (t5mp.exe 0x569DF0, CONFIRMED). Stock already
// holds ~20 current ones (perk/loadout icons + texts from every spawn, objective
// points), so build 14's 23 current menu elems lost rows 5+. Now: 10 current
// (selection slab + bar, 8 value texts), 18 archived (frame, 8 row labels).

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
	l.rows = 8;
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
	self notifyOnPlayerCommand( "an_dpad_left", "+actionslot 3" );
	self notifyOnPlayerCommand( "an_dpad_right", "+actionslot 4" );
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
	self an_speed_apply();
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
	h["brand"] = self an_hud_text( hx, l.top + 13, "left", "small", 1.1, accent, 1, 4, true );
	h["build"] = self an_hud_text( l.card_x + l.card_w - l.pad, l.top + 13, "right", "small", 1.1, dim, 1, 4, true );
	h["title"] = self an_hud_text( hx, l.top + 35, "left", "objective", 1.7, text, 1, 4, true );
	h["path"] = self an_hud_text( hx, l.top + 55, "left", "small", 1.1, dim, 1, 4, true );
	h["slab"] = self an_hud_rect( l.card_x, l.rows_y, l.card_w, l.row, ( 0.15, 0.15, 0.15 ), 0.95, 2, false );
	h["bar"] = self an_hud_rect( l.card_x, l.rows_y, 3, l.row, accent, 1, 3, false );
	h["marker"] = self an_hud_rect( l.left + 11, l.rows_y + 7, 7, 7, accent, 1, 3, true );
	h["thumb"] = self an_hud_rect( l.left + l.spine_w - 4, l.rows_y, 2, l.row, accent, 0.4, 3, true );
	h["hint"] = self an_hud_text( hx, l.rows_y + l.row * l.rows + 17, "left", "small", 1.0, dim, 1, 4, true );

	self.an_label = [];
	self.an_value = [];
	for ( i = 0; i < l.rows; i++ )
	{
		y = l.rows_y + i * l.row + int( l.row / 2 );
		self.an_label[i] = self an_hud_text( hx + 2, y, "left", "default", 1.3, text, 1, 4, true );
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
		case "perks": return "PERKS";
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
		rows[ rows.size ] = an_row( "sc", "Secondary Camo = Primary", "sc" );
		rows[ rows.size ] = an_row( "rf", "Rapid Fire", "rf" );
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
		rows[ rows.size ] = an_row( "page", "Perks", "perks" );
		rows[ rows.size ] = an_row( "afh", "Afterhit Prone", "afh" );
		rows[ rows.size ] = an_row( "afr", "Afterhit Reload", "afr" );
		rows[ rows.size ] = an_row( "stb", "Stall Bind", "stb" );
		rows[ rows.size ] = an_row( "ah", "Almost Hit Message", "ah" );
		rows[ rows.size ] = an_row( "cmd", "Save Settings", "save" );
		rows[ rows.size ] = an_row( "cmd", "Load Settings", "load" );
		rows[ rows.size ] = an_row( "back", "Back", "" );
	}
	else if ( page == "bindables" )
	{
		rows[ rows.size ] = an_row( "bindinfo", "Open This Menu", "menu" );
		rows[ rows.size ] = an_row( "bindinfo", "Give All Killstreaks", "killstreaks" );
		rows[ rows.size ] = an_row( "sb", "Smooth Action Bind", "sb" );
		rows[ rows.size ] = an_row( "bindinfo", "Smooth Action", "smooth" );
		rows[ rows.size ] = an_row( "bindinfo", "Stall / Unstall", "stall" );
		if ( self an_has_access() )
		{
			rows[ rows.size ] = an_row( "bindinfo", "Spawn Bot", "spawnbot" );
			rows[ rows.size ] = an_row( "bindinfo", "Move Bot to Crosshair", "tpbot" );
			rows[ rows.size ] = an_row( "bindinfo", "Setup / Unsetup Bot", "setupbot" );
		}
		rows = self an_edition_bind_rows( rows );
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
	else if ( page == "perks" )
	{
		keys = an_perk_keys();
		for ( i = 0; i < keys.size; i++ )
			rows[ rows.size ] = an_row( "perk", an_perk_name( keys[i] ), keys[i] );
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
		rows[ rows.size ] = an_row( "mv", "Constant UAV", "uav" );
		rows[ rows.size ] = an_row( "mv", "Friendly Bots", "fb" );
		rows[ rows.size ] = an_row( "mv", "Knife Lunge", "lunge" );
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
		case "stb":
			return self an_stall_text();
		case "dpadbind":
			return self an_dpad_bind_text( r.arg );
		case "sb":
			if ( self.pers["an_sb"] == "off" )
				return "OFF";
			return "DPAD " + an_upper( self.pers["an_sb"] );
		case "afr":
			return an_upper( self.pers["an_afr"] );
		case "ah":
			if ( self.pers["an_ah"] == "1" )
				return "ON";
			return "OFF";
		case "sc":
			if ( self.pers["an_sc"] == "1" )
				return "ON";
			return "OFF";
		case "perk":
		case "st":
		case "rf":
			if ( self.pers[ "an_" + r.arg ] == "1" )
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
		if ( r.kind == "cycle" || v == "CURRENT" || v == "EQUIPPED" || ( ( r.kind == "wset" || r.kind == "afh" || r.kind == "afr" || r.kind == "ah" || r.kind == "sc" || r.kind == "perk" || r.kind == "st" || r.kind == "rf" || r.kind == "mv" || r.kind == "loop" || r.kind == "mgr" || r.kind == "sb" || r.kind == "stb" || r.kind == "dpadbind" ) && v != "OFF" ) || ( r.kind == "vote" && self an_my_vote() == r.arg ) )
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
		case "afr":
		case "ah":
		case "sc":
		case "perk":
		case "st":
		case "rf":
		case "stb":
		case "dpadbind":
		case "sb":
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
		case "afr": self an_afterhit_reload_cycle(); break;
		case "ah": self an_almost_hit_toggle(); break;
		case "sc": self an_secondary_camo_toggle(); break;
		case "perk": self an_perk_toggle( arg ); break;
		case "st": self an_semtex_toggle(); break;
		case "rf": self an_rapid_toggle(); break;
		case "sb": self an_smooth_bind_cycle(); break;
		case "stb": self an_stall_cycle(); break;
		case "dpadbind": self an_dpad_bind_cycle( arg ); break;
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
			else if ( arg == "fb" )
				an_friendly_cycle();
			else if ( arg == "lunge" )
				an_lunge_cycle();
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
// bigger use radius (default off, Ankh 2026-10-13), Lower Death Barriers (OFF / 250 ... 2000).

an_movement_init()
{
	map = getdvar( "mapname" );
	if ( getdvar( "an_mv_map" ) != map )
	{
		setdvar( "an_mv_map", map );
		setdvar( "an_mv_ladder", "1" );
		setdvar( "an_mv_prone", "1" );
		setdvar( "an_mv_use", "0" );
		setdvar( "an_mv_barrier", "0" );
		setdvar( "an_mv_uav", "1" );
	}
	// first load of a build with this setting on an already running map
	if ( getdvar( "an_mv_uav" ) == "" )
		setdvar( "an_mv_uav", "1" );
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
	level thread an_zip_loop();
}

// Kowloon ziplines, free ride. Stock mp_kowloon.gsc zipline_player_func: puts the
// rider's moving_ent (script_model "tag_origin") at origin + 80, gives and switches to
// "zipline_mp", FreezeControlsAllowLook + DisableWeaponCycling, waits for
// "weapon_raising", PlayerLinkToDelta to moving_ent and MoveTo's it along the line;
// at the end SwitchToWeapon(saved weapon), EnableWeaponCycling, TakeWeapon zipline_mp.
// We let that "weapon_raising" through (the stock ride never hangs), then unlink,
// unfreeze, give the gun back and carry the player along moving_ent with
// setVelocity every frame: free look / spins, any weapon, equipment and streaks.
// Jump lets go (the stock ride carries on without the player). Kill switch:
// set an_zip_guns 0 (stock ride).
an_zip_loop()
{
	level endon( "game_ended" );
	if ( getdvar( "mapname" ) != "mp_kowloon" )
		return;
	an_log( "zipline free ride " + an_bool( getdvar( "an_zip_guns" ) != "0" ) );
	for ( ;; )
	{
		for ( i = 0; i < level.players.size; i++ )
		{
			player = level.players[i];
			if ( !isAlive( player ) || player an_is_bot() )
				continue;
			w = player getCurrentWeapon();
			if ( w != "zipline_mp" && w != "none" )
				player.an_zip_last = w;
			if ( getdvar( "an_zip_guns" ) != "0" && !isDefined( player.an_zip_busy ) && player hasWeapon( "zipline_mp" ) )
				player thread an_zip_ride();
		}
		wait 0.05;
	}
}

// The stock moving_ent sits at the rider's origin + 80 when the ride starts.
an_zip_find_ent( start )
{
	ents = getEntArray( "script_model", "classname" );
	best = undefined;
	best_d = 40;
	for ( i = 0; i < ents.size; i++ )
	{
		if ( !isDefined( ents[i].model ) || ents[i].model != "tag_origin" )
			continue;
		d = distance( ents[i].origin, start + ( 0, 0, 80 ) );
		if ( d < best_d )
		{
			best = ents[i];
			best_d = d;
		}
	}
	return best;
}

an_zip_ride()
{
	self endon( "disconnect" );
	self.an_zip_busy = true;
	ent = an_zip_find_ent( self.origin );
	self waittill_any_timeout_an( 2, "weapon_raising" );
	waittillframeend;
	if ( !isAlive( self ) || !isDefined( ent ) )
	{
		an_log( "zipline free ride skipped for " + self.name + " (ent " + an_bool( isDefined( ent ) ) + ")" );
		self an_zip_wait_end();
		return;
	}
	// the stock link keeps this offset (PlayerLinkToDelta)
	off = self.origin - ent.origin;
	self unlink();
	self freezeControlsAllowLook( false );
	self enableWeaponCycling();
	if ( isDefined( self.an_zip_last ) && self hasWeapon( self.an_zip_last ) )
		self switchToWeapon( self.an_zip_last );
	an_log( "zipline free ride " + self.name + " with " + self.an_zip_last );
	jumped = false;
	held = self jumpButtonPressed();
	while ( isAlive( self ) && self hasWeapon( "zipline_mp" ) )
	{
		jump = self jumpButtonPressed();
		if ( jump && !held )
		{
			jumped = true;
			break;
		}
		held = jump;
		self setVelocity( ( ent.origin + off - self.origin ) * 20 );
		wait 0.05;
	}
	if ( jumped )
		an_log( "zipline jump off " + self.name );
	self an_zip_wait_end();
}

an_zip_wait_end()
{
	while ( isAlive( self ) && self hasWeapon( "zipline_mp" ) )
		wait 0.05;
	self.an_zip_busy = undefined;
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
	// Constant UAV off: clear the sweep now (an_uav_loop stops renewing it)
	if ( key == "uav" && getdvar( d ) == "0" )
	{
		maps\mp\_radar::setTeamSpyplaneWrapper( "allies", 0 );
		maps\mp\_radar::setTeamSpyplaneWrapper( "axis", 0 );
	}
}

an_movement_text( key )
{
	if ( key == "fb" )
		return an_friendly_text();
	if ( key == "lunge" )
		return an_lunge_text();
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
			// the zipline ride sets the velocity itself
			if ( isDefined( p.an_zip_busy ) )
			{
				p.an_last_vz = v[2];
				continue;
			}
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

// ---------------------------------------------------------------- pistol move speed

// Every gun moves at pistol speed (Ankh 2026-10-13). Engine: speed = base * the held
// weapon's moveSpeedScale (adsMoveSpeedScale while aiming) * the script multiplier
// (bg_pmove.cpp PM_CmdScale). Pistols are 1.0 (weapon files, OAT dump); the others
// get 1 / their value. Aiming down sights gets the same multiplier.
an_weapon_move_scale( weapon )
{
	base = strTok( weapon, "_" )[0];
	switch ( base )
	{
		case "ak47": case "aug": case "commando": case "enfield": case "famas": case "fnfal":
		case "g11": case "galil": case "m14": case "m16":
		case "dragunov": case "l96a1": case "psg1": case "wa2000":
			return 0.95;
		case "hk21": case "m60": case "rpk": case "stoner63":
			return 0.875;
		case "china": case "m72": case "rpg": case "strela":
			return 0.8;
	}
	return 1;
}

an_speed_apply()
{
	if ( isDefined( self.an_menu_open ) && self.an_menu_open )
		return;
	weapon = self getCurrentWeapon();
	scale = 1;
	if ( isDefined( weapon ) && weapon != "none" && weapon != "" )
		scale = 1 / an_weapon_move_scale( weapon );
	self setMoveSpeedScale( scale );
}

an_speed_watch()
{
	self endon( "disconnect" );
	self endon( "death" );
	self notify( "an_speed_watch" );
	self endon( "an_speed_watch" );
	// No jump fatigue on the player's own game too: the server sets jump_slowdownEnable 0,
	// but the game predicts landings with its own copy (SUSPECTED it keeps 1).
	self setClientDvar( "jump_slowdownEnable", "0" );
	self an_speed_apply();
	for ( ;; )
	{
		self waittill( "weapon_change" );
		self an_speed_apply();
	}
}

// Perk toggles (per player, saved with the personal settings). ON gives the perk
// to every class, OFF takes it away even when the class has it. Specialty lists
// from the stock perk table (statstable.csv rows 161, 163, 167).
//   ps : Sleight of Hand Pro, default ON
//   pc : Scout Pro, default OFF
//   pa : Steady Aim Pro, default ON
//   pl : Lightweight Pro, default ON (row 151: movefaster|fallheight)
// Always on for humans: Marathon Pro's unlimited sprint. player_sprintUnlimited 1 is
// set on the server, but the player's game predicts sprint with its own copy; the
// perk bit travels in the player state (bg_pmove.cpp: perks[1] & 0x80000 = unlimited).

an_perk_keys()
{
	return strTok( "ps pc pa pl", " " );
}

an_perk_specialties( key )
{
	switch ( key )
	{
		case "ps": return strTok( "specialty_fastreload specialty_fastads", " " );
		case "pc": return strTok( "specialty_holdbreath specialty_fastweaponswitch", " " );
		case "pa": return strTok( "specialty_bulletaccuracy specialty_sprintrecovery specialty_fastmeleerecovery", " " );
		case "pl": return strTok( "specialty_movefaster specialty_fallheight", " " );
	}
	return [];
}

an_perk_name( key )
{
	switch ( key )
	{
		case "ps": return "Sleight of Hand Pro";
		case "pc": return "Scout Pro";
		case "pa": return "Steady Aim Pro";
		case "pl": return "Lightweight Pro";
	}
	return key;
}

an_perks_defaults()
{
	if ( !isDefined( self.pers["an_ps"] ) )
		self.pers["an_ps"] = "1";
	if ( !isDefined( self.pers["an_pc"] ) )
		self.pers["an_pc"] = "0";
	if ( !isDefined( self.pers["an_pa"] ) )
		self.pers["an_pa"] = "1";
	if ( !isDefined( self.pers["an_pl"] ) )
		self.pers["an_pl"] = "1";
	if ( !isDefined( self.pers["an_rf"] ) )
		self.pers["an_rf"] = "0";
}

// After every spawn and class change (stock giveLoadout clears perks first).
an_perks_apply()
{
	if ( !isAlive( self ) )
		return;
	self setPerk( "specialty_longersprint" );
	self setPerk( "specialty_unlimitedsprint" );
	keys = an_perk_keys();
	for ( k = 0; k < keys.size; k++ )
	{
		list = an_perk_specialties( keys[k] );
		on = ( self.pers[ "an_" + keys[k] ] == "1" );
		for ( i = 0; i < list.size; i++ )
		{
			if ( on )
				self setPerk( list[i] );
			else if ( self hasPerk( list[i] ) )
				self unsetPerk( list[i] );
		}
	}
	self an_rapid_perks();
}

an_perk_toggle( key )
{
	if ( self.pers[ "an_" + key ] == "1" )
		self.pers[ "an_" + key ] = "0";
	else
		self.pers[ "an_" + key ] = "1";
	self an_perks_apply();
}

// Rapid Fire (Ankh 2026-10-20; research in NOTES "rapid fire in the BO1 / Plutonium
// azza-style menus"). Same trick as Redemption / Revolt / Veruca: Sleight of Hand's fast
// reload + perk_weapReloadMultiplier 0.001, and the player HOLDS reload + fire, so every
// shot is followed by an instant reload and the gun fires again almost at once.
// The dvar is one value for the whole server and the player's game predicts with its own
// copy (bg_weapons.cpp:2699, reload states with perk bit fastreload), so it is set on the
// server and sent to every human. While anyone has Rapid Fire on, only Rapid Fire
// players keep specialty_fastreload (Sleight of Hand Pro gives it to everyone by default,
// perks.gsc), so nobody else gets instant reloads. Per player, Weapon page, pers an_rf,
// saved with the personal settings.

an_rapid_init()
{
	level thread an_rapid_watch();
}

an_rapid_active()
{
	for ( i = 0; i < level.players.size; i++ )
	{
		p = level.players[i];
		if ( an_is_human( p ) && isDefined( p.pers["an_rf"] ) && p.pers["an_rf"] == "1" )
			return true;
	}
	return false;
}

an_rapid_value()
{
	if ( an_rapid_active() )
		return "0.001";
	return "0.5";
}

// Catches the last Rapid Fire player leaving and settings loaded at join.
an_rapid_watch()
{
	level endon( "game_ended" );
	for ( ;; )
	{
		wait 1;
		// compared as numbers: the engine may print the value differently
		d = float( getdvar( "perk_weapReloadMultiplier" ) ) - float( an_rapid_value() );
		if ( d > 0.0001 || d < -0.0001 )
			an_rapid_update();
	}
}

an_rapid_update()
{
	v = an_rapid_value();
	setdvar( "perk_weapReloadMultiplier", v );
	an_log( "rapid fire: perk_weapReloadMultiplier " + v + " (server reads [" + getdvar( "perk_weapReloadMultiplier" ) + "])" );
	for ( i = 0; i < level.players.size; i++ )
	{
		p = level.players[i];
		if ( !an_is_human( p ) )
			continue;
		p setClientDvar( "perk_weapReloadMultiplier", v );
		p an_perks_apply();
	}
}

// Each spawn (an_weapons_spawned).
an_rapid_apply_player()
{
	self setClientDvar( "perk_weapReloadMultiplier", an_rapid_value() );
}

// From an_perks_apply, after the perk toggles.
an_rapid_perks()
{
	if ( !an_rapid_active() )
		return;
	if ( self.pers["an_rf"] == "1" )
		self setPerk( "specialty_fastreload" );
	else if ( self hasPerk( "specialty_fastreload" ) )
		self unsetPerk( "specialty_fastreload" );
}

an_rapid_toggle()
{
	if ( self.pers["an_rf"] == "1" )
		self.pers["an_rf"] = "0";
	else
	{
		self.pers["an_rf"] = "1";
		self iPrintLn( "Rapid Fire: hold reload + fire" );
	}
	an_log( "rapid fire " + self.name + " = " + self.pers["an_rf"] );
	an_rapid_update();
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
	text = an_file_read( an_save_root() + "managers.txt" );
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
	an_file_write( an_save_root() + "managers.txt", text );
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
// - always-on UAV for the human team; match bonus on the outcome screen; class change any time;
// - humans join the team the bot isn't on by themselves and can't switch teams.

// Plutonium docs: replaceFunc belongs in main(), which runs before the stock scripts.
an_rounds_main()
{
	replaceFunc( maps\mp\gametypes\_globallogic_player::freezePlayerForRoundEnd, ::an_freeze_for_round_end );
	// No AFK kick (Ankh 2026-10-12): stock kicks anyone not spawned after 90 s
	// (_globallogic_spawn.gsc:512); the engine idle timer is g_inactivity (0 = off).
	replaceFunc( maps\mp\gametypes\_globallogic_spawn::kickIfDontSpawn, ::an_no_afk_kick );
	setdvar( "g_inactivity", "0" );
	// Bot spawn freeze (server log: "potential infinite loop ... bot_give_random_perk",
	// ~2.5 s hitch per bot spawn): stock loops with no wait until the bot can afford a
	// perk, and online bots have no CoD points (_bot.gsc:1017/1138). The bot needs no perks.
	replaceFunc( maps\mp\gametypes\_bot::bot_give_random_perk, ::an_bot_no_perk );
	// Streaks that open the map to pick a spot always cancel (Ankh 2026-10-13): no map
	// UI, the streak is kept and the player switches back like a stock cancel
	// (select*Location returns false when the pick is cancelled, e.g. _napalm.gsc:89).
	replaceFunc( maps\mp\_napalm::selectNapalmLocation, ::an_streak_cancel );
	replaceFunc( maps\mp\_airstrike::selectAirstrikeLocation, ::an_streak_cancel );
	replaceFunc( maps\mp\_mortar::selectMortarLocation, ::an_streak_cancel );
	replaceFunc( maps\mp\_artillery::selectArtilleryLocation, ::an_streak_cancel );
	replaceFunc( maps\mp\_helicopter::selectHelicopterLocation, ::an_streak_cancel );
	// Kill popup: kill / headshot / long shot only, capped at +1000 (damage.gsc).
	replaceFunc( maps\mp\_medals::giveMedal, ::an_give_medal );
	replaceFunc( maps\mp\gametypes\_rank::updateRankScoreHUD, ::an_rank_score_hud );
}

an_streak_cancel( hardpointType )
{
	an_log( "streak cancel " + self.name + " " + hardpointType );
	return false;
}

an_no_afk_kick()
{
}

an_bot_no_perk( slot )
{
}

an_rounds_init()
{
	setdvar( "g_inactivity", "0" );
	level.an_old_dead_event = level.onDeadEvent;
	level.onDeadEvent = ::an_dead_event;
	level.an_old_end_game = level.onEndGame;
	level.onEndGame = ::an_on_end_game;
	an_teams_init();
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

// Players on a team with no class get their first custom class (as if picked in the
// class menu), and anyone who hasn't spawned this round is spawned mid-round. Stock
// maySpawn (_globallogic_spawn.gsc:55) refuses first spawns after the grace period;
// hasSpawned = true lets it pass, wantSafeSpawn skips "press to spawn" (:783), and
// stock spawnClient does the rest. Players who already spawned this round and died
// wait for the next round like stock. Never spawns with class "": that froze the T6
// server twice (stock isValidClass, _globallogic_utils.gsc:279). Kill switch:
// set an_late_spawn 0.
an_late_spawn()
{
	self endon( "disconnect" );
	level endon( "game_ended" );
	tries = 0;
	no_class = 0;
	for ( ;; )
	{
		wait 0.5;
		if ( getdvar( "an_late_spawn" ) == "0" )
			continue;
		if ( isAlive( self ) )
			return;
		if ( self.hasSpawned && tries == 0 )
			return;
		if ( !isDefined( game["state"] ) || game["state"] != "playing" || level.gameEnded )
			continue;
		if ( !isDefined( self.pers["team"] ) || ( self.pers["team"] != "allies" && self.pers["team"] != "axis" ) || self.sessionteam == "spectator" )
			continue;
		if ( !maps\mp\gametypes\_globallogic_utils::isValidClass( self.class ) || !maps\mp\gametypes\_globallogic_utils::isValidClass( self.pers["class"] ) )
		{
			// a second's grace so a class picked in the menu wins
			no_class++;
			if ( no_class >= 2 )
			{
				an_log( "default class custom1 for " + self.name );
				self maps\mp\gametypes\_globallogic_ui::menuClass( "custom1" );
				no_class = 0;
			}
			continue;
		}
		if ( level.inPrematchPeriod || level.inGracePeriod || level.inOvertime )
			continue;
		if ( !isDefined( self.pers["lives"] ) || self.pers["lives"] < 1 )
			continue;
		if ( isDefined( self.waitingToSpawn ) && self.waitingToSpawn )
			continue;
		if ( tries >= 3 )
		{
			an_log( "late spawn gave up " + self.name + " after " + tries + " tries" );
			return;
		}
		tries++;
		an_log( "late spawn " + self.name + " try " + tries + " team " + self.pers["team"] + " class " + self.class + " lives " + self.pers["lives"] + " session " + self.sessionstate );
		self.hasSpawned = true;
		self.wantSafeSpawn = true;
		// own thread: the stock wait ends on "end_respawn", which must not end this one
		self thread maps\mp\gametypes\_globallogic_spawn::spawnClient();
		self waittill_any_timeout_an( 3, "spawned_player" );
		wait 0.05;
		an_log( "late spawn result " + self.name + " alive " + an_bool( isAlive( self ) ) + " session " + self.sessionstate );
		if ( isAlive( self ) )
			return;
		// the stock wait was cut off and left waitingToSpawn set: retry
		self.waitingToSpawn = false;
	}
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
	if ( getdvar( "g_gametype" ) == "sd" && level.bombExploded && isDefined( level.an_bot_human_kill ) )
		level thread an_bomb_round_killcam();
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

// A bot killed by a human around the bomb explosion had no final killcam: the bomb
// ends the round through stock sd_endGame (sd.gsc:1063), which never calls
// startLastKillcam, unlike the eliminations (sd_endGameWithKillcam). The kill is
// recorded in level.lastKillCam by its death killcam (_killcam.gsc:204), or by
// startFinalKillcam when it lands < 1.75 s before the round end (that one also starts
// the killcam itself). Start it here; it plays at "play_final_killcam", after the
// round end screen (_globallogic.gsc startNextRound -> executePostRoundEvents).
an_bomb_round_killcam()
{
	for ( i = 0; i < 60 && !isDefined( level.lastKillCam ); i++ )
		wait 0.05;
	if ( !isDefined( level.lastKillCam ) )
	{
		an_log( "bomb round end: bot kill has no killcam recorded" );
		return;
	}
	an_log( "bomb round end: final killcam forced (bot killed " + ( getTime() - level.an_bot_human_kill ) + " ms before), in final killcam " + an_bool( level.inFinalKillcam ) );
	maps\mp\gametypes\_killcam::startLastKillcam();
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

// Always-on sweeping UAV for the team the humans are on (Manager -> Constant UAV,
// dvar an_mv_uav, default on, reset on a new map).
an_uav_loop()
{
	level endon( "game_ended" );
	wait 1;
	for ( ;; )
	{
		team = an_human_team();
		if ( getdvar( "an_mv_uav" ) != "0" && isDefined( team ) && !maps\mp\_radar::teamHasSatellite( team ) )
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
		{
			self an_perks_apply();
			self an_semtex_after_loadout();
			continue;
		}
		self an_class_regive();
		an_log( "class change " + self.name + " " + self.pers["class"] );
	}
}

// ---------------------------------------------------------------- teams

// Ankh 2026-10-12: players join the team the bot isn't on by themselves and can't
// switch. Stock team picks go through level.autoassign / level.allies / level.axis
// (_globallogic_ui.gsc:22); the bot joins through _bot.gsc's own copy, so these only
// see humans. Team balancing is off (it could move a human onto the bot's team).
an_teams_init()
{
	level.an_old_autoassign = level.autoassign;
	level.an_old_allies = level.allies;
	level.an_old_axis = level.axis;
	level.autoassign = ::an_team_auto;
	level.allies = ::an_team_allies;
	level.axis = ::an_team_axis;
	setdvar( "scr_teambalance", "0" );
	setdvar( "scr_" + getdvar( "g_gametype" ) + "_teamBalanceEndOfRound", "0" );
	level.teambalance = 0;
	level.teamBalanceEndOfRound = 0;
}

an_human_side()
{
	bot = an_bot_get();
	if ( isDefined( bot ) && isDefined( bot.pers["team"] ) && ( bot.pers["team"] == "allies" || bot.pers["team"] == "axis" ) )
		return getOtherTeam( bot.pers["team"] );
	team = an_human_team();
	if ( isDefined( team ) )
		return team;
	return "allies";
}

an_team_join( team )
{
	if ( team == "allies" )
		self [[ level.an_old_allies ]]();
	else
		self [[ level.an_old_axis ]]();
}

an_team_pick( wanted )
{
	if ( self an_is_friendly_bot() )
	{
		self an_friendly_set_team( self.pers["an_friendly"] );
		return;
	}
	if ( self an_is_bot() )
	{
		if ( wanted == "auto" )
			self [[ level.an_old_autoassign ]]();
		else
			self an_team_join( wanted );
		return;
	}
	side = an_human_side();
	on_team = isDefined( self.pers["team"] ) && ( self.pers["team"] == "allies" || self.pers["team"] == "axis" );
	if ( on_team && wanted != "auto" && wanted != self.pers["team"] )
	{
		self maps\mp\gametypes\_globallogic_ui::closeMenus();
		self iPrintLn( "Teams are locked" );
		return;
	}
	if ( on_team )
		side = self.pers["team"];
	an_log( "team " + self.name + " -> " + side + " (asked " + wanted + ")" );
	self an_team_join( side );
}

an_team_auto()
{
	self an_team_pick( "auto" );
}

an_team_allies()
{
	self an_team_pick( "allies" );
}

an_team_axis()
{
	self an_team_pick( "axis" );
}

// New players skip the team menu: the team the bot isn't on, then the class menu.
an_team_on_connect()
{
	self endon( "disconnect" );
	wait 0.1;
	if ( isDefined( self.pers["team"] ) && ( self.pers["team"] == "allies" || self.pers["team"] == "axis" ) )
		return;
	self an_team_pick( "auto" );
}

// Save / load (Anubis rules): personal settings saved per GUID on the server
// (scriptdata/anubis/player_<guid>.txt), loaded by themselves on join; never saved
// by themselves. Bot settings (setup, bot spot and sui spot for this map) are a
// separate manual save for managers. Restart loop, sui spot and bindable commands.

an_personal_keys()
{
	keys = strTok( "is ac ob nc fc afh afr ah sb ps pc pa pl st sc rf stb", " " );
	extra = an_dpad_bind_keys();
	for ( i = 0; i < extra.size; i++ )
		keys[ keys.size ] = extra[i];
	return keys;
}

an_player_file()
{
	return an_save_root() + "player_" + self getguid() + ".txt";
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
	self an_perks_apply();
	self an_semtex_apply();
	if ( isAlive( self ) )
	{
		self.an_sc_forced = true;
		self an_secondary_camo_apply( self.pers["an_sc"] == "1" );
		self.an_sc_forced = undefined;
	}
	self iPrintLn( "Saved settings loaded (" + n + ")" );
	an_log( "load " + self.name + " " + n + " values" );
}

an_valid_setting( key, v )
{
	switch ( key )
	{
		case "afh": return v == "off" || v == "stance" || v == "instant";
		case "afr": return v == "off" || v == "empty" || v == "normal";
		case "ah":
		case "sc":
		case "ps":
		case "pc":
		case "pa":
		case "pl":
		case "st":
		case "rf":
			return v == "0" || v == "1";
		case "sb":
		case "stb":
			return v == "off" || v == "up" || v == "down" || v == "left" || v == "right";
	}
	// dpad binds of the edition commands (dpadbind.gsc)
	if ( key.size > 3 )
		if ( getSubStr( key, 0, 3 ) == "db_" )
			return v == "off" || v == "up" || v == "down" || v == "left" || v == "right";
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
	old = an_file_read( an_save_root() + "bot_settings.txt" );
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
	if ( an_file_write( an_save_root() + "bot_settings.txt", text ) )
		self iPrintLn( "Bot settings saved" );
	an_log( "bot save by " + self.name );
}

an_load_bot()
{
	text = an_file_read( an_save_root() + "bot_settings.txt" );
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
	list = strTok( "menu spawnbot tpbot setupbot killstreaks smooth stall", " " );
	extra = strTok( an_edition_binds(), " " );
	for ( i = 0; i < extra.size; i++ )
		list[ list.size ] = extra[i];
	return list;
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
			case "stall":
				if ( !self.an_menu_open )
					self an_stall_toggle();
				break;
			default:
				self an_edition_bind( name );
				break;
		}
	}
}

// Semtex tactical (Anubis, T6 poughpack rules). INACTIVE since build 33 and off the menu
// since build 34 (Ankh: "we will revisit later"); see NOTES "Builds 30-32" / "Offhand cancel". BO1's tactical button only throws a
// grenade whose weapon file says offhandSlot "Tactical grenade" (bg_weapons.cpp:4126);
// stock sticky_grenade_mp is a lethal, and scripts can't change that. The mod ships
// weapons/mp/sticky_grenade_mp (stock main/iw_00.iwd file, only offhandSlot changed to Tactical; anubis_menu.iwd) and the
// server runs weapon_load_order "iwd", so that file wins over the fastfile one; every
// player's game needs it too (sent with setClientDvar below, used from the next map).
// - toggle "st" (Weapon page, saved, default OFF): tacticals taken, 2 semtex given;
// - a class with semtex as its lethal: semtex goes to the tactical button and the lethal
//   becomes a tomahawk (one weapon can only be held once), whether the toggle is on or not.
// Never setOffhandSecondaryClass with the semtex: a frag-class weapon is a script error
// there (g_client_script_cmd_mp.cpp PlayerCmd_setOffhandSecondaryClass).

an_semtex_active()
{
	return getdvar( "weapon_load_order" ) == "iwd";
}

an_semtex_on()
{
	return isDefined( self.pers["an_st"] ) && self.pers["an_st"] == "1";
}

an_semtex_connect()
{
	if ( !isDefined( self.pers["an_st"] ) )
		self.pers["an_st"] = "0";
	// Build 32 sent weapon_load_order "iwd" to every player here: their game then loaded
	// all ~550 raw weapon files and failed with "Hunk_AllocLowAlign failed on 3144 bytes
	// (total 5 MB)" (Ankh's console_mp.log). Never send it again.
	self an_raw_menus_on();
}

// Right after a loadout was given (spawn, class change): anything semtex held now
// came from the class, so it is the lethal.
an_semtex_after_loadout()
{
	self.an_semtex_life = false;
	self an_semtex_apply();
}

an_semtex_apply()
{
	if ( !isAlive( self ) || !an_semtex_active() )
		return;
	if ( !isDefined( self.an_semtex_life ) )
		self.an_semtex_life = false;
	lethal = self hasWeapon( "sticky_grenade_mp" ) && !self.an_semtex_life;
	if ( !lethal && !self an_semtex_on() )
		return;
	if ( lethal )
	{
		self giveWeapon( "hatchet_mp" );
		self setWeaponAmmoClip( "hatchet_mp", 1 );
		self switchToOffhand( "hatchet_mp" );
	}
	tacticals = strTok( "flash_grenade_mp concussion_grenade_mp willy_pete_mp tabun_gas_mp nightingale_mp", " " );
	for ( i = 0; i < tacticals.size; i++ )
		if ( self hasWeapon( tacticals[i] ) )
			self takeWeapon( tacticals[i] );
	if ( !self hasWeapon( "sticky_grenade_mp" ) )
		self giveWeapon( "sticky_grenade_mp" );
	self setWeaponAmmoClip( "sticky_grenade_mp", 2 );
	self.an_semtex_life = true;
	an_log( "semtex tactical " + self.name + " (lethal semtex " + an_bool( lethal ) + ")" );
}

an_semtex_toggle()
{
	if ( self an_semtex_on() )
	{
		self.pers["an_st"] = "0";
		self iPrintLn( "Semtex Tactical OFF (your class tactical comes back next spawn)" );
		return;
	}
	self.pers["an_st"] = "1";
	if ( !an_semtex_active() )
	{
		self iPrintLn( "Semtex Tactical needs the server's weapon file (weapon_load_order iwd)" );
		return;
	}
	if ( !isDefined( self.an_semtex_life ) )
		self.an_semtex_life = true;
	self an_semtex_apply();
}

// Stall bind (Ankh 2026-10-20, "dive stall"). The cfg version people share (g_gravity 0
// + g_speed 0, toggled with a vstr bind) means: no gravity and no steering, so a player
// in the air keeps the speed he had and glides on at the same height, still diving.
// Those dvars don't exist in BO1 (t5mp.exe has bg_gravity, no g_gravity / g_speed) and
// would hit the whole server. Per player instead: every server frame his vertical speed
// is cancelled and his horizontal speed put back. Second press, landing or 10 s ends it.
// Build 81 locked the player to an anchor (Revolt's mid-air stall): Ankh "it just freezes
// you in place" (the link stops all movement and the dive).
// Utilities -> Stall Bind: OFF / DPAD UP / DOWN / LEFT / RIGHT (pers an_stb, saved with the
// personal settings); console command "stall" for any key (bind <key> stall).

an_stall_watch()
{
	self endon( "disconnect" );
	if ( !isDefined( self.pers["an_stb"] ) )
		self.pers["an_stb"] = "off";
	for ( ;; )
	{
		cmd = self waittill_any_return( "an_up", "an_down", "an_dpad_left", "an_dpad_right" );
		b = self.pers["an_stb"];
		if ( b == "off" || self.an_menu_open )
			continue;
		// dpad up + aim opens the menu
		if ( ( b == "up" && cmd == "an_up" && !self adsButtonPressed() ) || ( b == "down" && cmd == "an_down" ) || ( b == "left" && cmd == "an_dpad_left" ) || ( b == "right" && cmd == "an_dpad_right" ) )
			self an_stall_toggle();
	}
}

an_stall_cycle()
{
	list = strTok( "off up down left right", " " );
	next = list[0];
	for ( i = 0; i < list.size; i++ )
		if ( list[i] == self.pers["an_stb"] && i + 1 < list.size )
			next = list[ i + 1 ];
	self.pers["an_stb"] = next;
}

an_stall_text()
{
	if ( !isDefined( self.pers["an_stb"] ) || self.pers["an_stb"] == "off" )
		return "OFF";
	return "DPAD " + an_upper( self.pers["an_stb"] );
}

an_stall_toggle()
{
	if ( isDefined( self.an_stalled ) )
	{
		self an_stall_release();
		return;
	}
	if ( !isAlive( self ) || level.gameEnded || isDefined( self.an_zip_busy ) || self isOnGround() )
		return;
	v = self getVelocity();
	self.an_stall_vel = ( v[0], v[1], 0 );
	self.an_stalled = true;
	self thread an_stall_hold();
	self thread an_stall_end_on_game();
	self thread an_stall_end_on_death();
	an_log( "stall " + self.name + " at " + self.origin + " speed " + int( length( self.an_stall_vel ) ) + " vz " + int( v[2] ) );
}

// 200 server frames = 10 s cap.
an_stall_hold()
{
	self endon( "an_stall_release" );
	self endon( "disconnect" );
	self endon( "death" );
	for ( i = 0; i < 200; i++ )
	{
		self setVelocity( self.an_stall_vel );
		wait 0.05;
		if ( self isOnGround() )
			break;
	}
	self an_stall_release();
}

an_stall_release()
{
	if ( !isDefined( self.an_stalled ) )
		return;
	self.an_stalled = undefined;
	self notify( "an_stall_release" );
	an_log( "stall released " + self.name );
}

an_stall_end_on_game()
{
	self endon( "an_stall_release" );
	self endon( "disconnect" );
	level waittill( "game_ended" );
	self an_stall_release();
}

// an_stall_hold ends on death without clearing the flag: clear it here
an_stall_end_on_death()
{
	self endon( "an_stall_release" );
	self endon( "disconnect" );
	self waittill( "death" );
	self an_stall_release();
}

// End-of-match map vote (Anubis): 5 random maps + Random, 15 s (Ankh 2026-10-13: was 3). Build 14 ran it in
// the intermission, where the scoreboard takes every key (server log: no menu keys
// from anyone during the vote). It now runs inside the stock onRoundEndGame hook,
// which stock endGame calls once, when the match is really over, before the outcome
// screen and the scoreboard (_globallogic.gsc endGame). Players are unfrozen but held
// in place (frozen players' dpad never reaches the server, build 1). Restart Loop
// skips the vote (and stays on through Maps-page changes); an empty server turns the loop
// off and goes back to the first map of its rotation.
// Dedicated: the result goes into sv_maprotationcurrent for the stock exitLevel;
// private match: host console "map".

an_vote_init()
{
	level.an_old_round_end_game = level.onRoundEndGame;
	level.onRoundEndGame = ::an_on_round_end_game;
}

an_on_round_end_game( winner )
{
	if ( isDefined( level.an_old_round_end_game ) )
		winner = [[ level.an_old_round_end_game ]]( winner );
	an_vote_run();
	return winner;
}

an_vote_run()
{
	humans = an_humans();
	if ( getdvar( "an_loop" ) == "1" && humans.size > 0 )
	{
		an_next_map( getdvar( "mapname" ), "restart loop" );
		return;
	}
	if ( humans.size == 0 )
	{
		// nobody left: the loop ends with the session (it now survives map changes)
		if ( getdvar( "an_loop" ) == "1" )
			an_log( "restart loop off (empty server)" );
		setdvar( "an_loop", "0" );
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
	line = "map vote";
	for ( i = 0; i < level.an_vote_choices.size; i++ )
		line = line + " " + level.an_vote_choices[i];
	an_log( line );

	while ( getTime() < level.an_vote_end )
	{
		wait 0.5;
		humans = an_humans();
		for ( i = 0; i < humans.size; i++ )
		{
			if ( isDefined( humans[i].an_menu_open ) && humans[i].an_menu_open && humans[i].an_page == "vote" )
				humans[i] an_menu_render();
			else
				humans[i] thread an_vote_open();
		}
	}

	winner = an_vote_result();
	humans = an_humans();
	for ( i = 0; i < humans.size; i++ )
	{
		if ( isDefined( humans[i].an_menu_open ) && humans[i].an_menu_open )
			humans[i] an_menu_close();
		humans[i] freeze_player_controls( true );
	}
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
	for ( n = 0; n < 5 && pool.size > 0; n++ )
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
	// held in place, not frozen, so the menu keys reach the server. Direct builtin:
	// stock freeze_player_controls( false ) does nothing once level.gameEnded is set
	// (_utility.gsc:2105), which left controller players frozen with a dead dpad.
	self freezeControls( false );
	self setMoveSpeedScale( 0 );
	self disableWeapons();
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
	if ( !isDefined( self.pers["an_afr"] ) )
		self.pers["an_afr"] = "off";
	if ( !isDefined( self.pers["an_ah"] ) )
		self.pers["an_ah"] = "1";
	if ( !isDefined( self.pers["an_sb"] ) )
		self.pers["an_sb"] = "off";
	// Secondary Camo = Primary (sesh "alt swap camos" idea), off by default
	if ( !isDefined( self.pers["an_sc"] ) )
		self.pers["an_sc"] = "0";
	self an_perks_defaults();
	self an_semtex_connect();
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
	self an_lunge_apply_player();
	self an_rapid_apply_player();
	self an_perks_apply();
	self an_semtex_after_loadout();
	self thread an_speed_watch();
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
	cc = self an_held_class_guns();
	if ( !isDefined( cc ) )
		return;
	if ( isDefined( cc["primary"] ) && isDefined( cc["primary_weapon_options"] ) )
		self.an_wopts[ cc["primary"] ] = int( cc["primary_weapon_options"] );
	if ( isDefined( cc["secondary"] ) && isDefined( cc["secondary_weapon_options"] ) )
		self.an_wopts[ cc["secondary"] ] = int( cc["secondary_weapon_options"] );
	if ( self.pers["an_sc"] == "1" )
		self an_secondary_camo_apply( true );
}

// The custom class whose guns the player holds right now: the class name first
// (self.class, stock giveLoadout's own index), else the first custom class whose primary
// AND secondary he holds. Looked up fresh every time (build 62 live log: a copy made from
// what was recorded at spawn pointed at Custom Class 1 while the player held his Custom
// Class 6 guns, until he switched classes).
an_held_class_guns()
{
	if ( !isDefined( self.custom_class ) )
	{
		self an_sc_note( "no custom classes" );
		return undefined;
	}
	n = -1;
	if ( isDefined( self.class ) && isSubStr( self.class, "CLASS_CUSTOM" ) )
	{
		c = self.class;
		n = int( c[ c.size - 1 ] ) - 1;
		if ( n == -1 )
			n = 9;
	}
	if ( n >= 0 && self an_holds_class_guns( n ) )
		return self.custom_class[n];
	keys = getArrayKeys( self.custom_class );
	for ( k = 0; k < keys.size; k++ )
	{
		if ( self an_holds_class_guns( keys[k] ) )
		{
			if ( self.pers["an_sc"] == "1" )
				an_log( "class guns " + self.name + " from custom class " + ( keys[k] + 1 ) + " (class name said " + ( n + 1 ) + ")" );
			return self.custom_class[ keys[k] ];
		}
	}
	self an_sc_note( "holds no custom class's primary + secondary" );
	return undefined;
}

an_holds_class_guns( n )
{
	if ( !isDefined( self.custom_class[n] ) )
		return false;
	cc = self.custom_class[n];
	if ( !isDefined( cc["primary"] ) || !isDefined( cc["secondary"] ) )
		return false;
	return self hasWeapon( cc["primary"] ) && self hasWeapon( cc["secondary"] );
}

// Build 61 diagnostic (build 60 live: toggled 6 times, no "secondary camo" line at all):
// says where the camo copy stopped, only for players who have the setting on or just
// toggled it.
an_sc_note( why )
{
	if ( self.pers["an_sc"] == "1" || isDefined( self.an_sc_forced ) )
		an_log( "secondary camo skipped " + self.name + ": " + why );
}

// Secondary Camo = Primary (Ankh 2026-10-13, like sesh's "alt swap camos"): the class
// secondary is given again with the primary's camo. Weapon options are packed by the
// engine's calcWeaponOptions (t5mp.exe 0x829740): camo = bits 0-5, lens / reticle / tag
// above; only the camo bits are copied. Only for primary-class guns in the secondary slot
// (overkill setups); pistols, launchers and specials keep theirs. on = false gives the
// class's own secondary camo back.
an_secondary_camo_apply( on )
{
	cc = self an_held_class_guns();
	if ( !isDefined( cc ) )
		return;
	if ( !isDefined( cc["primary"] ) || !isDefined( cc["secondary"] ) || !isDefined( cc["secondary_weapon_options"] ) )
	{
		self an_sc_note( "class has no primary / secondary / options" );
		return;
	}
	sec = cc["secondary"];
	if ( !an_is_primary_class_gun( sec ) )
	{
		self an_sc_note( sec + " isn't a primary-class gun" );
		return;
	}
	opts = int( cc["secondary_weapon_options"] );
	if ( on && isDefined( cc["primary_weapon_options"] ) )
	{
		prim = int( cc["primary_weapon_options"] );
		opts = opts - ( opts % 64 ) + ( prim % 64 );
	}
	if ( !isDefined( self.an_wopts ) )
		self.an_wopts = [];
	if ( isDefined( self.an_wopts[ sec ] ) && self.an_wopts[ sec ] == opts && !isDefined( self.an_sc_forced ) )
	{
		self an_sc_note( sec + " already has options " + opts );
		return;
	}
	self.an_wopts[ sec ] = opts;
	held = self getCurrentWeapon() == sec;
	clip = self getWeaponAmmoClip( sec );
	stock = self getWeaponAmmoStock( sec );
	self takeWeapon( sec );
	self giveWeapon( sec, 0, opts );
	self setWeaponAmmoClip( sec, clip );
	self setWeaponAmmoStock( sec, stock );
	if ( held )
		self switchToWeapon( sec );
	an_log( "secondary camo " + self.name + " " + sec + " options " + opts + " camo " + ( opts % 64 ) + " on " + an_bool( on ) );
}

// statstable groups of guns that are primaries in stock Create-a-Class.
an_is_primary_class_gun( weapon )
{
	if ( !isDefined( level.tbl_weaponIDs ) )
		return false;
	base = an_weapon_base( weapon );
	keys = getArrayKeys( level.tbl_weaponIDs );
	for ( k = 0; k < keys.size; k++ )
	{
		w = level.tbl_weaponIDs[ keys[k] ];
		if ( !isDefined( w ) || !isDefined( w["reference"] ) || !isDefined( w["group"] ) || w["reference"] != base )
			continue;
		g = w["group"];
		return g == "weapon_sniper" || g == "weapon_lmg" || g == "weapon_cqb" || g == "weapon_assault" || g == "weapon_smg";
	}
	return false;
}

an_secondary_camo_toggle()
{
	if ( self.pers["an_sc"] == "1" )
		self.pers["an_sc"] = "0";
	else
		self.pers["an_sc"] = "1";
	if ( isAlive( self ) )
	{
		self.an_sc_forced = true;
		self an_secondary_camo_apply( self.pers["an_sc"] == "1" );
		self.an_sc_forced = undefined;
	}
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

// Smooth action on a dpad button (Bindables -> Smooth Action Bind): OFF / up / down
// / left / right. The button keeps its stock use too (as IW4x smooth binds). ADS +
// dpad up stays the menu key, so a dpad up bind only fires without ADS.
an_smooth_bind_cycle()
{
	list = strTok( "off up down left right", " " );
	next = list[0];
	for ( i = 0; i < list.size; i++ )
		if ( list[i] == self.pers["an_sb"] && i + 1 < list.size )
			next = list[ i + 1 ];
	self.pers["an_sb"] = next;
}

an_smooth_bind_watch()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		cmd = self waittill_any_return( "an_up", "an_down", "an_dpad_left", "an_dpad_right" );
		b = self.pers["an_sb"];
		if ( !isDefined( b ) || b == "off" || self.an_menu_open || !isAlive( self ) )
			continue;
		if ( ( b == "up" && cmd == "an_up" && !self adsButtonPressed() ) || ( b == "down" && cmd == "an_down" ) || ( b == "left" && cmd == "an_dpad_left" ) || ( b == "right" && cmd == "an_dpad_right" ) )
			self an_smooth_action();
	}
}
