[Jump to table of contents](#default-extensions)

# Player

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):getUserGroup()

Get the usergroup of the provided player (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isAdmin()

Is the player an admin? (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isSuperAdmin()

Is the player a super admin? (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):shootPos()

Returns a players shoot position (8 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):eye()

Gets a player's view direction or an entity's forward direction (8 ops)

### ![Angle](Type-Angle.png "Angle") = ![Entity](Type-Entity.png "Entity"):eyeAngles()

Gets a player's view direction (8 ops)

### ![Angle](Type-Angle.png "Angle") = ![Entity](Type-Entity.png "Entity"):eyeAnglesVehicle()

Gets a player's view direction, relative to any vehicle they sit in. This function is needed to reproduce the behavior of cam controller. This is different from Vehicle:toLocal(Ply:eyeAngles()). (8 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):steamID()

Gets the steam ID of the player (5 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):steamID64()

Gets the Steam Community ID (aka Steam64) of the player (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):accountID()

Gets the account ID of the player. This is the significant portion of the Steam3 ID. Note that this is not guaranteed to be unique. (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):userID()

Gets the user ID/index of the player. This is used in player(userID) (5 ops)

### ![Entity](Type-Entity.png "Entity") = player(![Number](Type-Number.png "Number") Userid)

Gets the player with the specified user ID. See entity:userID() (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):armor()

Gets the armor of the player (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isCrouch()

Is the player crouching? (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isAlive()

Is the player or NPC alive? (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isFlashlightOn()

Returns 1 if the player has flashlight on, 0 otherwise (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isSpeaking()

Returns 1 if the player speaks, 0 otherwise (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isBot()

Returns 1 if the player is a bot, 0 otherwise (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):frags()

Returns the number of kills the player has made (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):deaths()

Returns the number of times the player died (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):team()

Returns the team number a player is on (5 ops)

### ![String](Type-String.png "String") = teamName(![Number](Type-Number.png "Number") Teamnum)

Returns the name of the team associated with the team number (5 ops)

### ![Number](Type-Number.png "Number") = teamScore(![Number](Type-Number.png "Number") Teamnum)

Returns the score of the team associated with the team number (5 ops)

### ![Array](Type-Array.png "Array") = teamMembers(![Number](Type-Number.png "Number") Teamnum)

Returns an array of players in the team associated with the team number (5 ops)

### ![Number](Type-Number.png "Number") = teamPlayers(![Number](Type-Number.png "Number") Teamnum)

Returns the number of players of the team associated with the team number (5 ops)

### ![Number](Type-Number.png "Number") = teamMemberCount(![Number](Type-Number.png "Number") Teamnum)

Returns the number of players of the team associated with the team number (5 ops)

### ![Number](Type-Number.png "Number") = teamDeaths(![Number](Type-Number.png "Number") Teamnum)

Returns the number of deaths of the team associated with the team number (5 ops)

### ![Number](Type-Number.png "Number") = teamFrags(![Number](Type-Number.png "Number") Teamnum)

Returns the number of kills of the team associated with the team number (5 ops)

### ![Vector](Type-Vector.png "Vector") = teamColor(![Number](Type-Number.png "Number") Index)

Returns the color of the team associated with the team number (5 ops)

### ![Array](Type-Array.png "Array") = teams()

Returns an array of all teams (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyForward()

Is the player pressing their forward key? (default W) (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyLeft()

Is the player pressing their left key? (default A) (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyBack()

Is the player pressing their back key? (default S) (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyRight()

Is the player pressing their right key? (default D) (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyJump()

Is the player pressing their jump key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyAttack1()

Is the player pressing their primary fire key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyAttack2()

Is the player pressing their secondary fire key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyUse()

Is the player pressing their use key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyReload()

Is the player pressing their reload key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyZoom()

Is the player pressing their zoom key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyWalk()

Is the player pressing their walk key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keySprint()

Is the player pressing their sprint key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyDuck()

Is the player pressing their crouch key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyLeftTurn()

Is the player pressing their Look left key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyRightTurn()

Is the player pressing their Look right key? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):keyPressed(![String](Type-String.png "String") Char)

Is the player pressing the KEY_ enumeration [S]? For example, 'W', 'K', '4', 'COMMA' (2 ops)

### runOnKeys(![Entity](Type-Entity.png "Entity") Ply, ![Number](Type-Number.png "Number") On)

DEPRECATED. Use 'event keyPressed(Player:entity, Key:string, Down:number, KeyBind:string)' instead! If set to 1, E2 will run when specified player presses/releases their key (20 ops)

### runOnKeys(![Entity](Type-Entity.png "Entity") Ply, ![Number](Type-Number.png "Number") On, ![Array](Type-Array.png "Array") Filter)

DEPRECATED. Use 'event keyPressed(Player:entity, Key:string, Down:number, KeyBind:string)' instead! (20 ops)

### runOnKeys(![Array](Type-Array.png "Array") Plys, ![Number](Type-Number.png "Number") On)

DEPRECATED. Use 'event keyPressed(Player:entity, Key:string, Down:number, KeyBind:string)' instead! (20 ops)

### runOnKeys(![Array](Type-Array.png "Array") Plys, ![Number](Type-Number.png "Number") On, ![Array](Type-Array.png "Array") Filter)

DEPRECATED. Use 'event keyPressed(Player:entity, Key:string, Down:number, KeyBind:string)' instead! (20 ops)

### ![Entity](Type-Entity.png "Entity") = keyClk()

DEPRECATED. Use 'event keyPressed(Player:entity, Key:string, Down:number, KeyBind:string)' instead! Returns the player that pressed/released the key if the E2 was triggered by runOnKeys (1 ops)

### ![Number](Type-Number.png "Number") = keyClk(![Entity](Type-Entity.png "Entity") Ply)

DEPRECATED. Use 'event keyPressed(Player:entity, Key:string, Down:number, KeyBind:string)' instead! Returns 1 if the E2 was triggered by the player pressing a key or -1 when releasing a key (1 ops)

### ![String](Type-String.png "String") = keyClkPressed()

DEPRECATED. Use 'event keyPressed(Player:entity, Key:string, Down:number, KeyBind:string)' instead! Returns the name of the pressed/released key that triggered the E2 (1 ops)

### ![String](Type-String.png "String") = keyClkPressedBind()

 (1 ops)

### runOnUse(![Number](Type-Number.png "Number") Value)

DEPRECATED. Use 'event playerUse(Player:entity, Entity:entity)' instead! If set to 1, E2 will run when a player presses E on the E2 (50 ops)

### ![Entity](Type-Entity.png "Entity") = useClk()

DEPRECATED. Use 'event playerUse(Player:entity, Entity:entity)' instead! Returns the player that used the E2, if the E2 was triggered by runOnUse (1 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isTyping()

Is the player typing a message in chat? (1 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):friends()

Returns an array of players on the prop protection friends list (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):trusts(![Entity](Type-Entity.png "Entity") Whom)

Is E2 on the prop protection friends list of E? (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canTool(![Entity](Type-Entity.png "Entity") Target, ![String](Type-String.png "String") Toolname)

Returns if the player can use a tool on this entity (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canPhysgun(![Entity](Type-Entity.png "Entity") Target)

Returns if the player can physgun this entity (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canPickup(![Entity](Type-Entity.png "Entity") Target)

Returns if the player can pickup this entity (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canPunt(![Entity](Type-Entity.png "Entity") Target)

Returns if the player can punt this entity (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canUse(![Entity](Type-Entity.png "Entity") Target)

Returns if the player can use this entity (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canDamage(![Entity](Type-Entity.png "Entity") Target)

Returns if the player can damage this entity (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canDrive(![Entity](Type-Entity.png "Entity") Target)

Returns if the player can prop drive this entity (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canProperty(![Entity](Type-Entity.png "Entity") Target, ![String](Type-String.png "String") Property)

Returns if the player can use a property on this entity (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canEditVariable(![Entity](Type-Entity.png "Entity") Target, ![String](Type-String.png "String") Key, ![String](Type-String.png "String") Val)

Returns if the player can edit a variable on this entity (2 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):steamFriends()

Returns a Array with E's steam friends on the server E is playing on (15 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isSteamFriend(![Entity](Type-Entity.png "Entity") Friend)

Returns if the given Entity is a steam friend of the first Entity (15 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):ping()

Returns the latency for player E (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):timeConnected()

Returns a players time connected to a server (5 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):vehicle()

Returns the entity of the vehicle that the specified player is in (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):inVehicle()

Is the player in a vehicle? (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):inNoclip()

Is the player in noclip mode? (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):inGodMode()

Returns whether the player has god mode or not (5 ops)

### ![Array](Type-Array.png "Array") = players()

Returns an array containing all players on the server (10 ops)

### ![Array](Type-Array.png "Array") = playersAdmins()

Returns an array containing all admins on the server (10 ops)

### ![Array](Type-Array.png "Array") = playersSuperAdmins()

Returns an array containing all super admins on the server (10 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):aimEntity()

Returns the entity that the entity is aiming at (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):aimPos()

Returns the point that the entity is looking at (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):aimNormal()

Returns a normalized directional vector perpendicular to the surface pointed at (10 ops)

### ![Bone](Type-Bone.png "Bone") = ![Entity](Type-Entity.png "Entity"):aimBone()

Returns the bone the player is currently aiming at (10 ops)

### runOnPlayerConnect(![Number](Type-Number.png "Number") Activate)

DEPRECATED. Use 'event playerConnected(Player:entity)' instead! If set to 0, the chip will no longer run on player connect events, otherwise it makes this chip execute when someone connects. Only needs to be called once, not in every execution (3 ops)

### ![Number](Type-Number.png "Number") = playerConnectClk()

DEPRECATED. Use 'event playerConnected(Player:entity)' instead! Returns 1 if the chip is being executed because of a player connect event. Returns 0 otherwise (3 ops)

### ![Entity](Type-Entity.png "Entity") = lastConnectedPlayer()

DEPRECATED. Use 'event playerConnected(Player:entity)' instead! Returns the last player to connect. (3 ops)

### runOnPlayerDisconnect(![Number](Type-Number.png "Number") Activate)

DEPRECATED. Use 'event playerDisconnected(Player:entity)' instead! If set to 0, the chip will no longer run on player disconnect events, otherwise it makes this chip execute when someone disconnects. Only needs to be called once, not in every execution (3 ops)

### ![Number](Type-Number.png "Number") = playerDisconnectClk()

DEPRECATED. Use 'event playerDisconnected(Player:entity)' instead! Returns 1 if the chip is being executed because of a player disconnect event. Returns 0 otherwise (3 ops)

### ![Entity](Type-Entity.png "Entity") = lastDisconnectedPlayer()

DEPRECATED. Use 'event playerDisconnected(Player:entity)' instead! Returns the last player to disconnect. Must be done while in a disconnectClk() as anytime after the player object is gone. (3 ops)

### runOnDeath(![Number](Type-Number.png "Number") Active)

DEPRECATED. Use 'event playerDeath(Victim:entity, Inflictor:entity, Attacker:entity)' instead! If set to 0, chip won't run on players dying (5 ops)

### ![Number](Type-Number.png "Number") = deathClk()

DEPRECATED. Use 'event playerDeath(Victim:entity, Inflictor:entity, Attacker:entity)' instead! Returns if the E2 was triggered by a death (5 ops)

### ![Number](Type-Number.png "Number") = lastDeathTime()

DEPRECATED. Use 'event playerDeath(Victim:entity, Inflictor:entity, Attacker:entity)' instead! Returns the last time a player died (5 ops)

### ![Number](Type-Number.png "Number") = lastDeathTime(![Entity](Type-Entity.png "Entity") Ply)

DEPRECATED. Use 'event playerDeath(Victim:entity, Inflictor:entity, Attacker:entity)' instead! Returns the last time given player died (5 ops)

### ![Entity](Type-Entity.png "Entity") = lastDeathVictim()

DEPRECATED. Use 'event playerDeath(Victim:entity, Inflictor:entity, Attacker:entity)' instead! Returns the last player to die (5 ops)

### ![Entity](Type-Entity.png "Entity") = lastDeathInflictor()

DEPRECATED. Use 'event playerDeath(Victim:entity, Inflictor:entity, Attacker:entity)' instead! Returns the entity that inflicted the last death (5 ops)

### ![Entity](Type-Entity.png "Entity") = lastDeathInflictor(![Entity](Type-Entity.png "Entity") Ply)

DEPRECATED. Use 'event playerDeath(Victim:entity, Inflictor:entity, Attacker:entity)' instead! Returns the entity that inflicted the given player's last death (5 ops)

### ![Entity](Type-Entity.png "Entity") = lastDeathAttacker()

DEPRECATED. Use 'event playerDeath(Victim:entity, Inflictor:entity, Attacker:entity)' instead! Returns the attacker who killed the last player to die (5 ops)

### ![Entity](Type-Entity.png "Entity") = lastDeathAttacker(![Entity](Type-Entity.png "Entity") Ply)

DEPRECATED. Use 'event playerDeath(Victim:entity, Inflictor:entity, Attacker:entity)' instead! Returns the attacker who killed the player provided in their last death (5 ops)

### ![Number](Type-Number.png "Number") = spawnClk()

DEPRECATED. Use 'event playerSpawn(Player:entity)' instead! Returns if the E2 was triggered by a player spawning (5 ops)

### runOnSpawn(![Number](Type-Number.png "Number") Activate)

DEPRECATED. Use 'event playerSpawn(Player:entity)' instead! If set to 0, chip won't run on players spawning (5 ops)

### ![Number](Type-Number.png "Number") = lastSpawnTime()

DEPRECATED. Use 'event playerSpawn(Player:entity)' instead! Returns the last time a player spawned (5 ops)

### ![Number](Type-Number.png "Number") = lastSpawnTime(![Entity](Type-Entity.png "Entity") Ply)

DEPRECATED. Use 'event playerSpawn(Player:entity)' instead! Returns the last time the given player spawned (5 ops)

### ![Entity](Type-Entity.png "Entity") = lastSpawnedPlayer()

DEPRECATED. Use 'event playerSpawn(Player:entity)' instead! Returns the last player to spawn (5 ops)

### ![Number](Type-Number.png "Number") = Usercmd:getMouseDeltaX()

Returns the mouse delta of this command on the x-axis (1 ops)

### ![Number](Type-Number.png "Number") = Usercmd:getMouseDeltaY()

Returns the mouse delta of this command on the y-axis (1 ops)

### ![Number](Type-Number.png "Number") = Usercmd:getForwardMove()

Returns the forward/back movement of this command (1 ops)

### ![Number](Type-Number.png "Number") = Usercmd:getSideMove()

Returns the strafe movement of this command (1 ops)

### ![Number](Type-Number.png "Number") = Usercmd:getUpMove()

Returns the up/down movement of this command (1 ops)

### ![Number](Type-Number.png "Number") = Movedata:getForwardSpeed()

Returns the forward/back speed of the movedata (1 ops)

### ![Number](Type-Number.png "Number") = Movedata:getSideSpeed()

Returns the strafe speed of the movedata (1 ops)

### ![Number](Type-Number.png "Number") = Movedata:getUpSpeed()

Returns the up/down speed of the movedata (1 ops)

### ![Number](Type-Number.png "Number") = Movedata:getMaxSpeed()

Returns the movedata's maximum movement speed (1 ops)

### ![Angle](Type-Angle.png "Angle") = Movedata:getMoveAngles()

Returns movedata's angles (1 ops)
