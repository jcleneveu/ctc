/**
 * Copyright (C) 2010-2011 Seeming
 * A big thanks to Hylith trxxrt and Zaran for their help and their support !
 *
 * This program is free software; you can redistribute it and/or
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

/**
 * @file ctc.as
 * Main file of the ctc gametype
 * based on the "flag's code" of "The Runner" by DrahtMaul
 */

 // variables <int>
int prcYesIcon;
int prcShockIcon;
int prcShellIcon;
int prcChickenIcon;
int prcCarrierIcon;
int modelChickenhand;
int prcAnnouncerChickenTaken;
int prcAnnouncerChickenDrop;
int prcAnnouncerPhilippe;
int prcAnnouncerPrecoce;
int prcAnnouncerPatron;
int announcesNumber = 0;
uint lastAnnounceTime = 0;
uint antiSimultaneousAnnounces = 0;

// constantes
const int MAX_NB_ANNOUNCER_ALLOWED = 3; // max number of crap sounds before, we consider it is spam
const uint NB_ANNOUNCER_TIMEOUT = 10000; // timeout of spam protection
const int RUN_SCOREINTERVAL = 3000;
const float chickenDropDistance = 2.5;

// Cvars
Cvar dmAllowPickup( "dm_allowPickup", "0", CVAR_ARCHIVE );
Cvar dmAllowPowerups( "dm_allowPowerups", "1", CVAR_ARCHIVE );
Cvar dmAllowPowerupDrop( "dm_powerupDrop", "1", CVAR_ARCHIVE );

// touch function of chicken entity
void chicken_touch( cEntity @ent, cEntity @other, const Vec3 planeNormal, int surfchickens )
{
    if ( @other == null || @other.client == null )
        return;

    if ( chicken.dropper == other.playerNum && chicken.droppedTime > levelTime )
        return;

    chicken.setCarrier( other );
}

// die function of chicken entity
void chicken_die( cEntity @ent, cEntity @inflicter, cEntity @attacker )
{
    chicken.spawn();
}

// think function of chicken entity
void chicken_think( cEntity @ent )
{
    chicken.spawn();
}

// chicken class
class Chicken
{
    cEntity @carrier;
    cEntity @chicken;
    cEntity @spawnpoint;
    uint nextScore;
    int dropper;
    uint droppedTime;
    int carrierTeam;

    Chicken()
    {
        @this.carrier = null;
        @this.chicken = null;
        this.nextScore = 0;
        this.dropper = -1;
        this.droppedTime = 0;
        this.carrierTeam = -1;
    }

    ~Chicken() {}

    void spawn()
    {
        cEntity @point = @GENERIC_SelectBestRandomSpawnPoint( null, "info_player_deathmatch" );
        @this.spawnpoint = @point;
        @this.carrier = null;
        this.spawn( point );
    }

    void spawn( cEntity @point )
    {
        if ( @this.chicken != null )
        {
            this.chicken.freeEntity();
            @this.chicken = null;
        }

        if ( @point == null )
            return;

        cEntity @chicken = G_SpawnEntity( "chicken" );
        Vec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );

        chicken.team = TEAM_PLAYERS;
        chicken.type = ET_GENERIC;
        chicken.effects |= EF_CARRIER ;
        chicken.setSize( mins, maxs );
        chicken.solid = SOLID_TRIGGER;
        chicken.modelindex = G_ModelIndex("models/ctc/poulet.md3");
        chicken.moveType = MOVETYPE_TOSS;
        chicken.svflags &= ~uint(SVF_NOCLIENT);

        chicken.origin = point.origin;
        chicken.linkEntity();
        chicken.addAIGoal();
        @this.chicken = @chicken;
        @this.chicken.touch = chicken_touch;
        @this.chicken.die = chicken_die;
        @this.chicken.think = chicken_think;
    }

    void setCarrier( cEntity @carrier )
    {
        this.chicken.reachedAIGoal();
        this.chicken.freeEntity();
        @this.chicken = null;
        carrier.effects |= EF_CARRIER ;

        @this.spawnpoint = null;
        @this.carrier = @carrier;
        this.carrier.client.inventoryClear();
        this.carrier.client.setPMoveFeatures( this.carrier.client.pmoveFeatures & ~int(PMFEAT_ITEMPICK) );
        this.carrier.modelindex2 = modelChickenhand;
        this.nextScore = levelTime + RUN_SCOREINTERVAL;
        this.carrier.client.addAward( S_COLOR_GREEN + "KEEP THE CHICKEN!!!" );

        G_AnnouncerSound( null, prcAnnouncerChickenTaken, GS_MAX_TEAMS, true, null );
        if ( this.carrierTeam == -1)
        {
            G_PrintMsg( null, carrier.client.name + " has captured the Chicken !\n" );
        }
        else
        {
            if ( this.carrierTeam == carrier.team )
            {
                G_PrintMsg( null, carrier.client.name + " has secured the Chicken !\n" );
            }
            else
            {
                G_PrintMsg( null, carrier.client.name + " has stolen the Chicken !\n" );
            }
        }
        this.carrierTeam = carrier.client.team;
    }

    void dropChicken()
    {
        this.carrier.effects &= ~uint( EF_CARRIER|EF_FLAG_TRAIL );
        this.carrier.modelindex2 = 0;
        G_AnnouncerSound( null, prcAnnouncerChickenDrop, GS_MAX_TEAMS, true, null );
        G_PrintMsg( null, carrier.client.name + " has dropped the Chicken !\n" );

        if ( ( G_PointContents( this.carrier.origin ) & CONTENTS_NODROP ) == 0 )
        {
            cEntity @carrier = @this.carrier;
            this.spawn( this.carrier );
            cEntity @chicken = this.chicken;
            cTrace tr;
            Vec3 end, dir, temp1, temp2;
            Vec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );
            carrier.angles.angleVectors( dir, temp1, temp2 );
            end = ( carrier.origin + ( 0.5 * ( maxs + mins ) ) ) + ( dir * 24 );

            tr.doTrace( carrier.origin, mins, maxs, end, carrier.entNum, MASK_SOLID );

            chicken.origin = tr.endPos;
            chicken.origin2 = tr.endPos;

            dir *= 200;
            dir.z = 250;

            chicken.velocity = dir;

            chicken.linkEntity();
        }
        else
            this.spawn();

        chicken.nextThink = levelTime + 15000;
        @this.carrier = null;
        @this.chicken = @chicken;

    }

    void passChicken()
    {
        cEntity @carrier = @this.carrier;
        this.carrier.modelindex2 = 0;
        this.carrier.effects &= ~uint( EF_CARRIER );
        this.carrier.client.setPMoveFeatures( this.carrier.client.pmoveFeatures | int(PMFEAT_ITEMPICK) );
            if ( gametype.isInstagib )
            {
                        this.carrier.client.inventoryGiveItem( WEAP_INSTAGUN );
                        this.carrier.client.inventorySetCount( AMMO_INSTAS, 1 );
                        this.carrier.client.inventorySetCount( AMMO_WEAK_INSTAS, 1 );
            }
            else
            {
                  this.carrier.client.inventoryGiveItem( WEAP_GUNBLADE );
                  if( ! dmAllowPickup.boolean )
                  {
                        cItem @item;
                        cItem @ammoItem;
                        
                        // give all weapons
                        for ( int i = WEAP_GUNBLADE + 1; i < WEAP_TOTAL; i++ )
                        {
                            if ( i == WEAP_INSTAGUN ) // dont add instagun...
                                continue;

                            this.carrier.client.inventoryGiveItem( i );

                            @item = @G_GetItem( i );

                            @ammoItem = @G_GetItem( item.weakAmmoTag );
                            if ( @ammoItem != null )
                                this.carrier.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

                            @ammoItem = @G_GetItem( item.ammoTag );
                            if ( @ammoItem != null )
                                this.carrier.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );
                        }
                  }
            }

        this.carrier.client.selectWeapon( -1 );
        G_AnnouncerSound( null, prcAnnouncerChickenDrop, GS_MAX_TEAMS, true, null );
        G_PrintMsg( null, carrier.client.name + " has dropped the Chicken !\n" );

        if ( ( G_PointContents( this.carrier.origin ) & CONTENTS_NODROP ) == 0 )
        {

            this.spawn( this.carrier );
            cEntity @chicken = this.chicken;
            cTrace tr;
            Vec3 end, dir, temp1, temp2;
            Vec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );
            carrier.angles.angleVectors( dir, temp1, temp2 );
            end = ( carrier.origin + ( 0.5 * ( maxs + mins ) ) ) + ( dir * 24 );

            tr.doTrace( carrier.origin, mins, maxs, end, carrier.entNum, MASK_SOLID );

            chicken.origin = tr.endPos;
            chicken.origin2 = tr.endPos;

            dir *= 250*chickenDropDistance;
            dir.z = 400;

            chicken.velocity = dir;

            chicken.linkEntity();
        }
        else
            this.spawn();


        this.dropper = carrier.playerNum;
        this.droppedTime = levelTime + 1000;
        chicken.nextThink = levelTime + 15000;
        @this.carrier = null;
        @this.chicken = @chicken;

    }

    void passChicken2()
    {
        cEntity @carrier = @this.carrier;
        this.carrier.modelindex2 = 0;
        this.carrier.effects &= ~uint( EF_CARRIER );
        this.carrier.client.setPMoveFeatures( this.carrier.client.pmoveFeatures | int(PMFEAT_ITEMPICK) | int(PMFEAT_GUNBLADEAUTOATTACK) );
            if ( gametype.isInstagib )
            {
                        this.carrier.client.inventoryGiveItem( WEAP_INSTAGUN );
                        this.carrier.client.inventorySetCount( AMMO_INSTAS, 1 );
                        this.carrier.client.inventorySetCount( AMMO_WEAK_INSTAS, 1 );
            }
            else
            {
                  this.carrier.client.inventoryGiveItem( WEAP_GUNBLADE );
                  if( ! dmAllowPickup.boolean )
                  {
                        cItem @item;
                        cItem @ammoItem;
                  
                        // give all weapons
                        for ( int i = WEAP_GUNBLADE + 1; i < WEAP_TOTAL; i++ )
                        {
                            if ( i == WEAP_INSTAGUN ) // dont add instagun...
                                continue;

                            this.carrier.client.inventoryGiveItem( i );

                            @item = @G_GetItem( i );

                            @ammoItem = @G_GetItem( item.weakAmmoTag );
                            if ( @ammoItem != null )
                                this.carrier.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

                            @ammoItem = @G_GetItem( item.ammoTag );
                            if ( @ammoItem != null )
                                this.carrier.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );
                        }
                  }
            }
        this.carrier.client.selectWeapon( -1 );
        G_AnnouncerSound( null, prcAnnouncerChickenDrop, GS_MAX_TEAMS, true, null );
        G_PrintMsg( null, carrier.client.name + " has dropped the Chicken ! \n" );

        if ( ( G_PointContents( this.carrier.origin ) & CONTENTS_NODROP ) == 0 )
        {

            this.spawn( this.carrier );
            cEntity @chicken = this.chicken;
            cTrace tr;
            Vec3 end, dir, temp1, temp2;
            Vec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );
            carrier.angles.angleVectors( dir, temp1, temp2 );
            end = ( carrier.origin + ( 0.5 * ( maxs + mins ) ) ) + ( dir * 24 );

            tr.doTrace( carrier.origin, mins, maxs, end, carrier.entNum, MASK_SOLID );

            chicken.origin = tr.endPos;
            chicken.origin2 = tr.endPos;

            dir *= 200*chickenDropDistance;
            dir.z = 250;

            chicken.velocity = dir;

            chicken.linkEntity();
        }
        else
            this.spawn();


        this.dropper = carrier.playerNum;
        this.droppedTime = levelTime + 1000;
        chicken.nextThink = levelTime + 15000;
        @this.carrier = null;
        @this.chicken = @chicken;

    }

    void think()
    {
        if ( @this.carrier == null || @this.carrier.client == null )
            return;
        this.carrier.effects |= EF_GODMODE;
        if ( this.carrier.health < 125 )
            this.carrier.health += frameTime * 0.001f;

        if ( this.carrier.client.armor < 75 )
            this.carrier.client.armor += frameTime * 0.0005f;

        if ( this.nextScore <= levelTime )
        {
            this.carrier.client.stats.addScore( 1 );
            G_GetTeam(this.carrier.team).stats.addScore( 1 );
            this.nextScore = levelTime + RUN_SCOREINTERVAL;
        }
    }

    void damage( cEntity @target, cEntity @attacker, cEntity @inflicter )
    {
        if ( @target == null )
            return;

        if ( @attacker == null )
            return;

        if ( @target == @this.carrier )
            return;
    }
}

Chicken chicken;


//Scores
void run_playerKilled( cEntity @target, cEntity @attacker, cEntity @inflicter )
{
    if ( @target.client == null )
        return;
    cTeam @team;

    @team = @G_GetTeam( target.team );

    if ( @target == @chicken.carrier )
    {
        chicken.dropChicken();
        if ( @attacker != null && @attacker.client != null && target.team != attacker.client.team )
            attacker.client.stats.addScore( 1 );
    }

    if ( @attacker != null && @attacker.client != null && target.team == attacker.client.team )
    {
    attacker.client.stats.addScore( -5 );
    }
    else if ( @attacker != null && @attacker.client != null && target.team != attacker.client.team )
    {
        attacker.client.stats.addScore( 1 );
    }

    //Drop items
    if ( ( G_PointContents( target.origin ) & CONTENTS_NODROP ) == 0 )
    {
        // drop the weapon
        if ( target.client.weapon > WEAP_GUNBLADE )
        {
            GENERIC_DropCurrentWeapon( target.client, true );
        }

        target.dropItem( AMMO_PACK_WEAK );

        if ( dmAllowPowerupDrop.boolean )
        {
            if ( target.client.inventoryCount( POWERUP_QUAD ) > 0 )
            {
                target.dropItem( POWERUP_QUAD );
                target.client.inventorySetCount( POWERUP_QUAD, 0 );
            }

            if ( target.client.inventoryCount( POWERUP_SHELL ) > 0 )
            {
                target.dropItem( POWERUP_SHELL );
                target.client.inventorySetCount( POWERUP_SHELL, 0 );
            }
        }
    }
}

/**
 * Called when a client sends a command
 * @param client Handler to the client
 * @param cmdString The name of the command
 * @param argsString The arguments of the command
 * @param argc The number of arguments
 */
bool GT_Command( cClient @client, String &cmdString, String &argsString, int argc )
{
    if ( cmdString == "drop" )
    {
        String token;

        for ( int i = 0; i < argc; i++ )
        {
            token = argsString.getToken( i );
            if ( token.len() == 0 )
                break;

            if ( token == "fullweapon" )
            {
                GENERIC_DropCurrentWeapon( client, true );
                GENERIC_DropCurrentAmmoStrong( client );
            }
            else if ( token == "weapon" )
            {
                GENERIC_DropCurrentWeapon( client, true );
            }
            else if ( token == "strong" )
            {
                GENERIC_DropCurrentAmmoStrong( client );
            }

            else
            {
                GENERIC_CommandDropItem( client, token );
            }
        }

        return true;
    }

    else if ( cmdString == "classaction2" )
    {
        if ( @client.getEnt() == @chicken.carrier )
            chicken.passChicken();
    }

    else if ( cmdString == "classaction1" )
    {
        if ( @client.getEnt() == @chicken.carrier )
            chicken.passChicken2();
    }
    
    else if ( cmdString == "philippe" )
    {
        if( antiSimultaneousAnnounces < levelTime )
        {
             if( announcesNumber < MAX_NB_ANNOUNCER_ALLOWED )
             {
                  G_GlobalSound( CHAN_AUTO, prcAnnouncerPhilippe );
                  antiSimultaneousAnnounces = levelTime + 5505;
                  lastAnnounceTime = levelTime + 5505;
                  announcesNumber++;
             }
             else 
             {
                  G_PrintMsg( @client.getEnt(), "STOP SPAM YOU FOOOOOL ! " + ( ( lastAnnounceTime - levelTime + NB_ANNOUNCER_TIMEOUT ) / 1000 ) + " seconds remaining...\n" );
             }
        }
        else 
        {
             //G_PrintMsg( @client.getEnt(), "plz wait for crap sound to finish\n" );
        }
    }

    else if ( cmdString == "precoce" )
    {
       if( antiSimultaneousAnnounces < levelTime )
        {
             if( announcesNumber < MAX_NB_ANNOUNCER_ALLOWED )
             {
                  G_GlobalSound( CHAN_AUTO, prcAnnouncerPrecoce );
                  antiSimultaneousAnnounces = levelTime + 1969;
                  lastAnnounceTime = levelTime + 1969;
                  announcesNumber++;
             }
             else 
             {
                 G_PrintMsg( @client.getEnt(), "STOP SPAM YOU FOOOOOL ! " + ( ( lastAnnounceTime - levelTime + NB_ANNOUNCER_TIMEOUT ) / 1000 ) + " seconds remaining...\n" );
             }
        }
        else 
        {
             //G_PrintMsg( @client.getEnt(), "plz wait for crap sound to finish\n" );
        }
    }

    else if ( cmdString == "patron" )
    {
       if( antiSimultaneousAnnounces < levelTime )
        {
             if( announcesNumber < MAX_NB_ANNOUNCER_ALLOWED )
             {
                  G_GlobalSound( CHAN_AUTO, prcAnnouncerPatron );
                  antiSimultaneousAnnounces = levelTime + 2636;
                  lastAnnounceTime = levelTime + 2636;
                  announcesNumber++;
             }
             else 
             {
                  G_PrintMsg( @client.getEnt(), "STOP SPAM YOU FOOOOOL ! " + ( ( lastAnnounceTime - levelTime + NB_ANNOUNCER_TIMEOUT ) / 1000 ) + " seconds remaining...\n" );
             }
        }
        else 
        {
             //G_PrintMsg( @client.getEnt(), "plz wait for crap sound to finish\n" );
        }
    }
    
    else if ( cmdString == "help" )
    {
        String response = "";

        response += "^1You don't know how to play ? Read this :\n";
        response += "\n";
        response += "^3A chicken randomly spawn in the map, to earn points, a member of your team must catch the chicken and keep it as long as possible.\n";
        response += "^3(your team will earn 1 point every 5 seconds)\n";
        response += "^3But ^1BEWARE^3 ! The chicken's carrier have no weapons, so if a member of your team has the chicken, DEFEND HIM !\n";
        response += "^3(You will get points for that :D)\n";
        response += "^3Conversely, if a member of the opposing team has the chicken, KILL HIM !\n";
        response += "^3(You will also get points for that :D)\n";
        response += "^1TIPS ^3: You can launch the chicken witch ClassAction1(short distance) or ClassAction2 (long distance)\n";
        G_PrintMsg( client.getEnt(), response );
        return true;
    }
    else if ( cmdString == "callvotevalidate" )
    {
        String votename = argsString.getToken( 0 );
        if ( votename == "dm_allow_powerups" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( voteArg != "0" && voteArg != "1" )
            {
                client.printMessage( "Callvote " + votename + " expects a 1 or a 0 as argument\n" );
                return false;
            }

            if ( voteArg == "0" && !dmAllowPowerups.boolean )
            {
                client.printMessage( "Powerups are already disallowed\n" );
                return false;
            }

            if ( voteArg == "1" && dmAllowPowerups.boolean )
            {
                client.printMessage( "Powerups are already allowed\n" );
                return false;
            }

            return true;
        }

        if ( votename == "dm_powerup_drop" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( voteArg != "0" && voteArg != "1" )
            {
                client.printMessage( "Callvote " + votename + " expects a 1 or a 0 as argument\n" );
                return false;
            }

            if ( voteArg == "0" && !dmAllowPowerupDrop.boolean )
            {
                client.printMessage( "Powerup drop is already disallowed\n" );
                return false;
            }

            if ( voteArg == "1" && dmAllowPowerupDrop.boolean )
            {
                client.printMessage( "Powerup drop is already allowed\n" );
                return false;
            }

            return true;
        }
        
        if ( votename == "dm_allow_pickup" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( voteArg != "0" && voteArg != "1" )
            {
                client.printMessage( "Callvote " + votename + " expects a 1 or a 0 as argument\n" );
                return false;
            }

            if ( voteArg == "0" && !dmAllowPickup.boolean )
            {
                client.printMessage( "Weapon pickup is already disallowed\n" );
                return false;
            }

            if ( voteArg == "1" && dmAllowPickup.boolean )
            {
                client.printMessage( "Weapon pickup is already allowed\n" );
                return false;
            }

            return true;
        }

        client.printMessage( "Unknown callvote " + votename + "\n" );
        return false;
    }
    else if ( cmdString == "callvotepassed" )
    {
        String votename = argsString.getToken( 0 );
        if ( votename == "dm_allow_powerups" )
        {
            if( argsString.getToken( 1 ).toInt() > 0 )
                dmAllowPowerups.set( 1 );
            else
                dmAllowPowerups.set( 0 );

            //Force a match restart to update
            match.launchState( MATCH_STATE_POSTMATCH );
            return true;
        }
        
        if ( votename == "dm_allow_pickup" )
        {
            if( argsString.getToken( 1 ).toInt() > 0 )
                dmAllowPickup.set( 1 );
            else
                dmAllowPickup.set( 0 );

            //Force a match restart to update
            match.launchState( MATCH_STATE_POSTMATCH );
            return true;
        }

        if ( votename == "dm_powerup_drop" )
        {
            if( argsString.getToken( 1 ).toInt() > 0 )
                dmAllowPowerupDrop.set( 1 );
            else
                dmAllowPowerupDrop.set( 0 );
        }

        return true;
    }
    else if( cmdString == "cvarinfo" )
    {
        return true;
    }

    return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( cEntity @self )
{
    cEntity @goal;
    cBot @bot;

    @bot = @self.client.getBot();

    if ( @bot == null )
        return false;

    float offensiveStatus = GENERIC_OffensiveStatus( self );

    //Loop all the goal entities
    for ( int i = 0; @bot.getGoalEnt( i ) != null; i++ )
    {
        @goal = @bot.getGoalEnt( i );

        //By now, always full-ignore not solid entities
        if ( goal.solid == SOLID_NOT )
        {
            bot.setGoalWeight( i, 0 );
            continue;
        }

        if ( @goal.client != null )
        {
            //Someone is tag so assign him as priority
            if ( @chicken.carrier != null )
            {
                if ( @goal == @chicken.carrier )
                {
                    bot.setGoalWeight( i, GENERIC_PlayerWeight( self, goal ) * offensiveStatus * 2.0f );
                }
                else
                {
                    bot.setGoalWeight( i, 0 );
                }
            }
            else
            {
                bot.setGoalWeight( i, 0 );
            }
        }

        if ( goal.classname == "chicken" )
            bot.setGoalWeight( i, 7.0f * offensiveStatus );
    }

    return true;
}

/**
 * A player is about to spawn. Select an spawnpoint for him.
 * Returning null makes the game code select a random "info_player_deathmatch".
 */
cEntity @GT_SelectSpawnPoint( cEntity @self )
{
    if ( self.team == TEAM_ALPHA )
    {
        return GENERIC_SelectBestRandomSpawnPoint( self, "team_CTF_alphaspawn" );
    }
    else if ( self.team == TEAM_BETA )
    {
        return GENERIC_SelectBestRandomSpawnPoint( self, "team_CTF_betaspawn" );
    }
    else
    {
        return null;
    }

}

String @GT_ScoreboardMessage( uint maxlen )
{
    String scoreboardMessage = "";
    String entry;
    cTeam @team;
    cEntity @ent;
    int i, t, carrierIcon, readyIcon;

    for ( t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
    {
        @team = @G_GetTeam( t );

        // &t = team tab, team tag, team score, team ping
        entry = "&t " + t + " " + team.stats.score + " " + team.ping + " ";
        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;

        for ( i = 0; @team.ent( i ) != null; i++ )
        {
            @ent = @team.ent( i );

            if ( ( ent.effects & EF_CARRIER ) != 0 )
                carrierIcon = prcChickenIcon;
            else if ( ( ent.effects & EF_QUAD ) != 0 )
                carrierIcon = prcShockIcon;
            else if ( ( ent.effects & EF_SHELL ) != 0 )
                carrierIcon = prcShellIcon;
            else
                carrierIcon = 0;

            if ( ent.client.isReady() )
                readyIcon = prcYesIcon;
            else
                readyIcon = 0;

            int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;

            // "Name Score Frags TKs Ping C R"
            entry = "&p " + playerID + " "
                    + ent.client.clanName + " "
                    + ent.client.stats.score + " "
                    + ent.client.ping + " "
                    + carrierIcon + " "
                    + readyIcon + " ";

            if ( scoreboardMessage.len() + entry.len() < maxlen )
                scoreboardMessage += entry;
        }
    }

    return scoreboardMessage;
}


/**
 * This function is called by the game code when any of the events considered
 * relevant to scores happen. At this point those events are:
 * enterGame - A client has finished connecting and enters a new level
 * connect - A client just connected
 * disconnect - A client just disconnected
 * dmg - A client has inflicted some damage
 * kill - A client has killed some other entity
 * award - A client receives an award
 * pickup - A client picked up an item (use args.getToken( 0 ) to get the item's classname)
 * projectilehit
 */
void GT_scoreEvent( cClient @client, String &score_event, String &args )
{
    cEntity @attacker = null;
    if ( @client != null )
        @attacker = @client.getEnt();

    int arg1 = args.getToken( 0 ).toInt();
    int arg2 = args.getToken( 1 ).toInt();

    if ( score_event == "dmg" )
    {
        chicken.damage( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );
    }
    else if ( score_event == "kill" )
    {
        // target, attacker, inflictor
        run_playerKilled( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );
    }
    else if ( score_event == "award" )
    {
    }
}

/**
 * This function is called each time a player is respawned.
 * It is called right after the player is set up, but before
 * it's assigned solid state. Note that Respawning happens
 * as much for being made not-solid (ghosting) as for being put
 * in the game. For example, when a player changes team he is
 * respawned twice. Once is moved to ghost, and then again is moved
 * to the world as part of the new team.
 * Respawning, of course, also happens after a death, to be put back in the game.
 * The most usual activity to perform in this function is giving spawn items
 * to the player.
 */
void GT_playerRespawn( cEntity @ent, int old_team, int new_team )
{

    if ( @ent == @chicken.carrier )
        chicken.spawn();

    if ( ent.isGhosting() )
        return;

    if ( gametype.isInstagib )
    {
        ent.client.inventoryGiveItem( WEAP_INSTAGUN );
        ent.client.inventorySetCount( AMMO_INSTAS, 1 );
        ent.client.inventorySetCount( AMMO_WEAK_INSTAS, 1 );
    }
    else
    {
        cItem @item;
        cItem @ammoItem;


        // the gunblade can't be given (because it can't be dropped)
        ent.client.inventorySetCount( WEAP_GUNBLADE, 1 );

        @item = @G_GetItem( WEAP_GUNBLADE );

        @ammoItem = @G_GetItem( item.ammoTag );
        if ( @ammoItem != null )
            ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

        @ammoItem = @G_GetItem( item.weakAmmoTag );
        if ( @ammoItem != null )
            ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

        if ( match.getState() <= MATCH_STATE_WARMUP || ! dmAllowPickup.boolean )
        {
            ent.client.inventoryGiveItem( ARMOR_YA );
            ent.client.inventoryGiveItem( ARMOR_YA );

            // give all weapons
            for ( int i = WEAP_GUNBLADE + 1; i < WEAP_TOTAL; i++ )
            {
                if ( i == WEAP_INSTAGUN ) // dont add instagun...
                    continue;

                ent.client.inventoryGiveItem( i );

                @item = @G_GetItem( i );

                @ammoItem = @G_GetItem( item.weakAmmoTag );
                if ( @ammoItem != null )
                    ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

                @ammoItem = @G_GetItem( item.ammoTag );
                if ( @ammoItem != null )
                    ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );
            }
        }
        else
        {
            ent.health = ent.maxHealth * 1.25;
        }
    }

    // select rocket launcher if available
    ent.client.selectWeapon( -1 ); // auto-select best weapon in the inventory

    // add a teleportation effect
    ent.respawnEffect();
}

/**
 * This function is called very game frame. It's used for anything that requires
 * continuous thinking. This is the equivalent of a game server tik.
 */
void GT_ThinkRules()
{
    if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished() )
        match.launchState( match.getState() + 1 );

    if ( match.getState() >= MATCH_STATE_POSTMATCH )
        return;
        
    if ( lastAnnounceTime + NB_ANNOUNCER_TIMEOUT < levelTime && announcesNumber != 0 )
        announcesNumber = 0;

    chicken.think();

    // check maxHealth rule
    for ( int i = 0; i < maxClients; i++ )
    {
        cEntity @ent = @G_GetClient( i ).getEnt();

        if ( ent.client.state() >= CS_SPAWNED && ent.team != TEAM_SPECTATOR )
        {
            if ( ent.health > ent.maxHealth )
                ent.health -= ( frameTime * 0.001f );

            GENERIC_ChargeGunblade( ent.client );
        }


        ent.client.setHUDStat( STAT_IMAGE_SELF, 0 );
        ent.client.setHUDStat( STAT_IMAGE_OTHER, 0 );
        ent.client.setHUDStat( STAT_IMAGE_ALPHA, 0 );
        ent.client.setHUDStat( STAT_IMAGE_BETA, 0 );
        ent.client.setHUDStat( STAT_MESSAGE_SELF, 0 );
        ent.client.setHUDStat( STAT_MESSAGE_OTHER, 0 );
        ent.client.setHUDStat( STAT_MESSAGE_ALPHA, 0 );
        ent.client.setHUDStat( STAT_MESSAGE_BETA, 0 );

        if ( ent.team == TEAM_ALPHA )
        {
            if ( @chicken.carrier != null )
            {
                if ( chicken.carrier.team == TEAM_ALPHA )
                    ent.client.setHUDStat( STAT_IMAGE_SELF, prcCarrierIcon );
                else if ( chicken.carrier.team == TEAM_BETA )
                    ent.client.setHUDStat( STAT_IMAGE_OTHER, prcCarrierIcon );
            }
        }
        else if ( ent.team == TEAM_BETA )
        {
            if ( @chicken.carrier != null )
            {
                if ( chicken.carrier.team == TEAM_ALPHA )
                    ent.client.setHUDStat( STAT_IMAGE_OTHER, prcCarrierIcon );
                else if ( chicken.carrier.team == TEAM_BETA )
                    ent.client.setHUDStat( STAT_IMAGE_SELF, prcCarrierIcon );
            }
        }
        else if ( ent.client.chaseActive == false )
        {
            if ( @chicken.carrier != null )
            {
                if ( chicken.carrier.team == TEAM_ALPHA )
                    ent.client.setHUDStat( STAT_IMAGE_ALPHA, prcCarrierIcon );
                else if ( chicken.carrier.team == TEAM_BETA )
                    ent.client.setHUDStat( STAT_IMAGE_BETA, prcCarrierIcon );
            }
        }
    }
}

/**
 * The game has detected the end of the match state, but it
 * doesn't advance it before calling this function.
 * This function must give permission to move into the next
 * state by returning true.
 */
bool GT_MatchStateFinished( int incomingMatchState )
{
    if ( match.getState() <= MATCH_STATE_WARMUP
         && incomingMatchState > MATCH_STATE_WARMUP
         && incomingMatchState < MATCH_STATE_POSTMATCH )
    {
        match.startAutorecord();
    }

    if ( match.getState() == MATCH_STATE_POSTMATCH )
        match.stopAutorecord();

    return true;
}

/**
 * A new match state is launched. The gametype gets in
 * this function a chance to set up everything for the new state.
 */
void GT_MatchStateStarted()
{
    switch ( match.getState() )
    {
    case MATCH_STATE_WARMUP:
        gametype.pickableItemsMask = gametype.spawnableItemsMask;
        gametype.dropableItemsMask = gametype.spawnableItemsMask;
        GENERIC_SetUpWarmup();
        break;

    case MATCH_STATE_COUNTDOWN:
        gametype.pickableItemsMask = 0; // disallow item pickup
        gametype.dropableItemsMask = 0; // disallow item drop
        GENERIC_SetUpCountdown();
        break;

    case MATCH_STATE_PLAYTIME:
        gametype.pickableItemsMask = gametype.spawnableItemsMask;
        gametype.dropableItemsMask = gametype.spawnableItemsMask;
        GENERIC_SetUpMatch();
        chicken.spawn();
        break;

    case MATCH_STATE_POSTMATCH:
        gametype.pickableItemsMask = 0; // disallow item pickup
        gametype.dropableItemsMask = 0; // disallow item drop
        GENERIC_SetUpEndMatch();
        break;

    default:
        break;
    }
}

/**
 * The gametype is shutting down cause of a match restart or map change
 */
void GT_Shutdown()
{
}

/**
 * After gametype initialization the map entities are spawned by the game code.
 * Every entity is ready to go at this point, but nothing has yet started.
 * The gametype has, in this function, a chance to spawn it's own entities.
 * Note that this isn't in reference to map entities, those have their own spawn
 * functions.
 * An example could be a gametype which spawns a few runes at random places.
 */
void GT_SpawnGametype()
{
    chicken.spawn();
}

/**
 * Gametype Initialization function.
 * Called each time the gametype is started, including server initialization,
 * map loads and match restarts. This function sets up the game code for the
 * gametype by defining the cGametypeDesc object. It's also recommended to do
 * files precache and Cvar registration in this function.
 *
 * Important: This function is called before any entity is spawned, and
 * spawning entities from it is forbidden. If you want to make any entity
 * spawning at initialization do it in GT_SpawnGametype, which is called
 * right after the map entities spawning.
 */
void GT_InitGametype()
{
    gametype.title = "Catch The Chicken !";
    gametype.version = "0.5";
    gametype.author = "Random Warsowian";

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.name + ".cfg" ) )
    {
        String config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.title + "' gametype configuration file\n"
                + "// This config will be executed each time the gametype is started\n"
                + "\n\n// map rotation\n"
                + "set g_maplist \"wdm1 wdm2 wdm4 wdm6 wdm7 wdm10 wdm12 wdm13 wdm14 wca1 wca3 wctf1 wctf3 wctf5 wctf6 \" // list of maps in automatic rotation\n"
                + "set g_maprotation \"2\"   // 0 = same map, 1 = in order, 2 = random\n"
                + "\n// game settings\n"
                + "set g_scorelimit \"150\"\n"
                + "set g_timelimit \"0\"\n"
                + "set g_warmup_timelimit \"2\"\n"
                + "set g_match_extendedtime \"0\"\n"
                + "set g_allow_falldamage \"0\"\n"
                + "set g_allow_selfdamage \"0\"\n"
                + "set g_allow_teamdamage \"1\"\n"
                + "set g_allow_stun \"1\"\n"
                + "set g_teams_maxplayers \"0\"\n"
                + "set g_teams_allow_uneven \"0\"\n"
                + "set g_countdown_time \"5\"\n"
                + "set g_maxtimeouts \"3\" // -1 = unlimited\n"
                + "set g_challengers_queue \"0\"\n"
                + "set dm_allowPowerups \"1\"\n"
                + "set dm_powerupDrop \"1\"\n"
                + "\necho \"" + gametype.name + ".cfg executed\"\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.name + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.name + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.name + ".cfg silent" );
    }

    gametype.spawnableItemsMask = 0;
    
    if ( dmAllowPickup.boolean )
        gametype.spawnableItemsMask = ( IT_WEAPON | IT_AMMO | IT_ARMOR | IT_HEALTH | IT_POWERUP );
        
    if ( ! dmAllowPowerups.boolean )
        gametype.spawnableItemsMask &= ~( IT_POWERUP );

    if ( gametype.isInstagib )
        gametype.spawnableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);

    gametype.respawnableItemsMask = gametype.spawnableItemsMask;
    gametype.dropableItemsMask = gametype.spawnableItemsMask;
    gametype.pickableItemsMask = gametype.spawnableItemsMask;

    gametype.isTeamBased = true;
    gametype.isRace = false;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 0;

    gametype.ammoRespawn = 20;
    gametype.armorRespawn = 25;
    gametype.weaponRespawn = 5;
    gametype.healthRespawn = 15;
    gametype.powerupRespawn = 90;
    gametype.megahealthRespawn = 20;
    gametype.ultrahealthRespawn = 40;

    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    gametype.mathAbortDisabled = false;
    gametype.shootingDisabled = false;
    gametype.infiniteAmmo = false;
    gametype.canForceModels = true;
    gametype.canShowMinimap = false;
    gametype.teamOnlyMinimap = false;

    gametype.spawnpointRadius = 256;

    if ( gametype.isInstagib )
        gametype.spawnpointRadius *= 2;

    // set spawnsystem type
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );

    // define the scoreboard layout
    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %l 48 %p 18 %p 18" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Ping C R" );

    //Precache chicken's "In Hand" model
    modelChickenhand = G_ModelIndex( "models/ctc/pouletmain.md3" );

    // precache images that can be used by the scoreboard
    prcYesIcon = G_ImageIndex( "gfx/hud/icons/vsay/yes" );
    prcShockIcon = G_ImageIndex( "gfx/hud/icons/powerup/quad" );
    prcShellIcon = G_ImageIndex( "gfx/hud/icons/powerup/warshell" );
    prcChickenIcon = G_ImageIndex( "gfx/ctc/ChickenIcon.tga" );
    prcCarrierIcon = G_ImageIndex( "gfx/ctc/chickenHUD.tga" );
    // precache Chicken's sounds
    prcAnnouncerChickenTaken = G_SoundIndex( "sounds/ctc/taken" );
    prcAnnouncerChickenDrop = G_SoundIndex( "sounds/ctc/drop" );
    // precache Crap sounds
    prcAnnouncerPhilippe = G_SoundIndex( "sounds/ctc/philippe" );
    prcAnnouncerPrecoce = G_SoundIndex( "sounds/ctc/precoce" );
    prcAnnouncerPatron = G_SoundIndex( "sounds/ctc/patron" );


    // add commands
    G_RegisterCommand( "drop" );
    G_RegisterCommand( "help" );
    G_RegisterCommand( "philippe" );
    G_RegisterCommand( "precoce" );
    G_RegisterCommand( "patron" );
    G_RegisterCommand( "classaction1" );
    G_RegisterCommand( "classaction2" );
    
    G_RegisterCallvote( "dm_allow_pickup", "<1 or 0>", "Enable or disable weapon pickup" );
    G_RegisterCallvote( "dm_allow_powerups", "<1 or 0>", "Enable or disable powerup spawning" );
    G_RegisterCallvote( "dm_powerup_drop", "<1 or 0>", "Enable or disable powerup drop" );

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}
