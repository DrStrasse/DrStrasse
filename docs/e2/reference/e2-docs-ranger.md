[Jump to table of contents](#default-extensions)

# Ranger

### rangerPersist(![Number](Type-Number.png "Number") Persist)

Passing 0 (the default) resets all ranger flags and filters every execution and after calling ranger/rangerOffset. Passing anything else will make the flags and filters persist until they're changed again (1 ops)

### rangerReset()

Resets all ranger flags and filters (1 ops)

### ![String](Type-String.png "String") = rangerFlags()

Returns the ranger flags as a string (1 ops)

### rangerFlags(![String](Type-String.png "String") Flags)

Sets the ranger flags. S can be any combination of I=ignore world, W=hit water, E=hit entities and Z=default to zero (1 ops)

### rangerHitWater(![Number](Type-Number.png "Number") Hitwater)

Default is 0, if any other value is given it will hit water (1 ops)

### rangerHitEntities(![Number](Type-Number.png "Number") Hitentities)

Default is 1, if value is given as 0 it will ignore entities (1 ops)

### rangerIgnoreWorld(![Number](Type-Number.png "Number") Ignoreworld)

Default is 0, if any other value is given it will ignore world (1 ops)

### rangerDefaultZero(![Number](Type-Number.png "Number") Defaultzero)

If given any value other than 0 it will default the distance data to zero when nothing is hit (1 ops)

### rangerWhitelist(![Number](Type-Number.png "Number") Whitelistmode)

 (1 ops)

### rangerFilter(![Entity](Type-Entity.png "Entity") Ent)

Feed entities you don't want the trace to hit (10 ops)

### rangerFilter(![Array](Type-Array.png "Array") Filter)

Feed an array of entities you don't want the trace to hit (1 ops)

### ![RangerData](Type-RangerData.png "RangerData") = noranger()

Returns an invalid ranger (1 ops)

### ![RangerData](Type-RangerData.png "RangerData") = ![Entity](Type-Entity.png "Entity"):eyeTrace()

Performs a quick trace from the player's eye. Equivalent to rangerOffset(16384, E:shootPos(), E:eye()), but faster. Does not respect filters or ranger flags (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = ![Entity](Type-Entity.png "Entity"):eyeTraceCursor()

Same as eyeTrace, except it also works when the player (for example) is holding down C (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = ranger(![Number](Type-Number.png "Number") Distance)

You input max range, it returns ranger data (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = ranger(![Number](Type-Number.png "Number") Distance, ![Number](Type-Number.png "Number") Xskew, ![Number](Type-Number.png "Number") Yskew)

Same as above with added inputs for X and Y skew (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = ranger(![Entity](Type-Entity.png "Entity") Ent, ![Number](Type-Number.png "Number") Distance)

Same as ranger(distance): You input max range, it returns ranger data, only used on another entity (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerAngle(![Number](Type-Number.png "Number") Distance, ![Number](Type-Number.png "Number") Xangle, ![Number](Type-Number.png "Number") Yangle)

You input the distance, x-angle and y-angle (both in degrees) it returns ranger data (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerOffset(![Vector](Type-Vector.png "Vector") From, ![Vector](Type-Vector.png "Vector") To)

You input two vector points, it returns ranger data (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerOffset(![Number](Type-Number.png "Number") Distance, ![Vector](Type-Vector.png "Vector") From, ![Vector](Type-Vector.png "Vector") Direction)

You input the range, a position vector, and a direction vector and it returns ranger data (20 ops)

### ![Number](Type-Number.png "Number") = ![RangerData](Type-RangerData.png "RangerData"):distance()

Outputs the distance from the rangerdata input, else depends on rangerDefault (2 ops)

### ![Vector](Type-Vector.png "Vector") = ![RangerData](Type-RangerData.png "RangerData"):position()

Outputs the position of the input ranger data trace IF it hit anything, else returns (0,0,0) (2 ops)

### ![Vector](Type-Vector.png "Vector") = ![RangerData](Type-RangerData.png "RangerData"):pos()

Returns the hit position. The difference between this function and RD:position() is that if you start the trace inside the world, RD:position() will return the position at which the trace EXITS the world. RD:pos(), however, will continue on and return the hit position outside the wall you started the trace in (2 ops)

### ![Entity](Type-Entity.png "Entity") = ![RangerData](Type-RangerData.png "RangerData"):entity()

Returns the entity of the input ranger data trace IF it hit an entity, else returns nil (2 ops)

### ![Bone](Type-Bone.png "Bone") = ![RangerData](Type-RangerData.png "RangerData"):bone()

Returns the bone of the input ranger data trace IF it hit a bone, else returns nil (2 ops)

### ![Number](Type-Number.png "Number") = ![RangerData](Type-RangerData.png "RangerData"):hit()

Returns 1 if the input ranger data hit anything and 0 if it didn't (2 ops)

### ![Vector](Type-Vector.png "Vector") = ![RangerData](Type-RangerData.png "RangerData"):hitNormal()

Outputs a normalized vector perpendicular to the surface the ranger is pointed at (2 ops)

### ![Number](Type-Number.png "Number") = ![RangerData](Type-RangerData.png "RangerData"):fraction()

Returns a number between 0-1 which represents the percentage of the distance between the start & hit position of the trace. StartPos + (EndPos-StartPos):normalized() * RD:fraction() * (EndPos-StartPos):Length() is equal to RD:pos() (2 ops)

### ![Number](Type-Number.png "Number") = ![RangerData](Type-RangerData.png "RangerData"):hitWorld()

Returns 1 if the trace hit the world, 0 otherwise (2 ops)

### ![Number](Type-Number.png "Number") = ![RangerData](Type-RangerData.png "RangerData"):hitSky()

Returns 1 if the trace hit the sky, 0 otherwise (2 ops)

### ![Vector](Type-Vector.png "Vector") = ![RangerData](Type-RangerData.png "RangerData"):positionLeftSolid()

Returns the position at which the trace left the world, if it was started inside the world. Else return the trace's Start Position (2 ops)

### ![Number](Type-Number.png "Number") = ![RangerData](Type-RangerData.png "RangerData"):distanceLeftSolid()

Returns the distance between the position at which the trace left the world and the trace's Start Position (2 ops)

### ![Number](Type-Number.png "Number") = ![RangerData](Type-RangerData.png "RangerData"):fractionLeftSolid()

Same as RD:fraction() except it represents the distance between the start position and the LeftSolid position (2 ops)

### ![Number](Type-Number.png "Number") = ![RangerData](Type-RangerData.png "RangerData"):startSolid()

Returns 1 if the trace was started inside the world, else 0 (2 ops)

### ![String](Type-String.png "String") = ![RangerData](Type-RangerData.png "RangerData"):matType()

Returns the material type (ie wood, metal, dirt, flesh, etc) (2 ops)

### ![String](Type-String.png "String") = ![RangerData](Type-RangerData.png "RangerData"):hitGroup()

Returns the hit group (ie chest, face, left arm, right leg, etc) (2 ops)

### ![String](Type-String.png "String") = ![RangerData](Type-RangerData.png "RangerData"):hitTexture()

Returns the texture of the surface the ranger is pointed at (2 ops)

### ![Table](Type-Table.png "Table") = ![RangerData](Type-RangerData.png "RangerData"):toTable()

Converts the trace data into an E2-style table and returns it. Remember that this returns the raw data, so for matType and hitGroup, it is recommend that you use the functions instead of this table (2 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerHull(![Number](Type-Number.png "Number") Distance, ![Vector](Type-Vector.png "Vector") Size)

Inputs: Distance, Hull BoxSize (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerHull(![Number](Type-Number.png "Number") Distance, ![Vector](Type-Vector.png "Vector") Mins, ![Vector](Type-Vector.png "Vector") Maxs)

Input: Distance, Hull MinSize, Hull MaxSize (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerHull(![Number](Type-Number.png "Number") Distance, ![Number](Type-Number.png "Number") Xskew, ![Number](Type-Number.png "Number") Yskew, ![Vector](Type-Vector.png "Vector") Size)

Inputs: Distance, X Skew, Y Skew, Hull BoxSize (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerHull(![Number](Type-Number.png "Number") Distance, ![Number](Type-Number.png "Number") Xskew, ![Number](Type-Number.png "Number") Yskew, ![Vector](Type-Vector.png "Vector") Mins, ![Vector](Type-Vector.png "Vector") Maxs)

Inputs: Distance, X Skew, Y Skew, Hull MinSize, Hull MaxSize (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerAngleHull(![Number](Type-Number.png "Number") Distance, ![Number](Type-Number.png "Number") Xangle, ![Number](Type-Number.png "Number") Yangle, ![Vector](Type-Vector.png "Vector") Size)

Inputs: Distance, X Angle, Y Angle, Hull BoxSize (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerAngleHull(![Number](Type-Number.png "Number") Distance, ![Number](Type-Number.png "Number") Xangle, ![Number](Type-Number.png "Number") Yangle, ![Vector](Type-Vector.png "Vector") Mins, ![Vector](Type-Vector.png "Vector") Maxs)

Inputs: Distance, X Angle, Y Angle, Hull MinSize, Hull MaxSize (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerOffsetHull(![Vector](Type-Vector.png "Vector") Startpos, ![Vector](Type-Vector.png "Vector") Endpos, ![Vector](Type-Vector.png "Vector") Size)

Inputs: StartPos, EndPos, Hull BoxSize (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerOffsetHull(![Vector](Type-Vector.png "Vector") Startpos, ![Vector](Type-Vector.png "Vector") Endpos, ![Vector](Type-Vector.png "Vector") Mins, ![Vector](Type-Vector.png "Vector") Maxs)

Inputs: StartPos, EndPos, Hull MinSize, Hull MaxSize (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerOffsetHull(![Number](Type-Number.png "Number") Distance, ![Vector](Type-Vector.png "Vector") Startpos, ![Vector](Type-Vector.png "Vector") Direction, ![Vector](Type-Vector.png "Vector") Size)

Inputs: Distance, StartPos, Direction, Hull BoxSize (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerOffsetHull(![Number](Type-Number.png "Number") Distance, ![Vector](Type-Vector.png "Vector") Startpos, ![Vector](Type-Vector.png "Vector") Direction, ![Vector](Type-Vector.png "Vector") Mins, ![Vector](Type-Vector.png "Vector") Maxs)

Inputs: Distance, StartPos, Direction, Hull MinSize, Hull MaxSize (20 ops)

### ![RangerData](Type-RangerData.png "RangerData") = rangerOffsetHull(![Entity](Type-Entity.png "Entity") Ent, ![Vector](Type-Vector.png "Vector") From, ![Vector](Type-Vector.png "Vector") To)

Use entity collision box for the ranger. Inputs: Entity, StartPos, EndPos (20 ops)
