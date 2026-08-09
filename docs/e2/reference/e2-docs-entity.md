[Jump to table of contents](#default-extensions)

# Entity

### ![Entity](Type-Entity.png "Entity") = entity(![Number](Type-Number.png "Number") Id)

Gets the entity associated with the id (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):id()

Gets the numeric id of an entity (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):creationID()

 (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):creationTime()

Returns the time the entity was created on, relative to curtime. (5 ops)

### ![Entity](Type-Entity.png "Entity") = noentity()

Returns an invalid entity (5 ops)

### ![Entity](Type-Entity.png "Entity") = world()

Returns the world entity (5 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):name()

Gets the name of a player (5 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):type()

Gets the class of an entity (5 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):getClass()

 (5 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):model()

Gets the model of an entity (5 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):owner()

Gets the owner of an entity (5 ops)

### ![Array](Type-Array.png "Array") = entities()

Returns an array containing all entities on the map (100 ops)

### ![Table](Type-Table.png "Table") = ![Entity](Type-Entity.png "Entity"):keyvalues()

Returns the keyvalue table of an entity (20 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):setEditProperty(![String](Type-String.png "String") Key, ![String](Type-String.png "String") Value)

Sets an editable property to the string-encoded value. Returns 1 if it succeeded (20 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):getEditProperty(![String](Type-String.png "String") Key)

Returns a string encoding of the editable property (20 ops)

### ![Table](Type-Table.png "Table") = ![Entity](Type-Entity.png "Entity"):getEditData()

Returns a look-up table of editable values on an editable entity (30 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isEditable()

Returns 1 if the entity has editable properties (1 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):pos()

Gets the position of the entity (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):forward()

Gets the forward direction of the entity 2) (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):right()

Gets the right direction of the entity (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):up()

Gets the up direction of the entity (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):vel()

Gets the velocity of the entity (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):velL()

Gets the local velocity of the entity (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):velAtPoint(![Vector](Type-Vector.png "Vector") Worldposition)

Gets the world velocity of a point in world coordinates attached to the entity (5 ops)

### ![Angle](Type-Angle.png "Angle") = ![Entity](Type-Entity.png "Entity"):angVel()

Gets the angular velocity of the entity (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):angVelVector()

Returns rotation axis, velocity and direction given as the vector's direction, magnitude and sense (5 ops)

### ![Vector](Type-Vector.png "Vector") = sunDirection()

Returns the vector direction that points towards the sun (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):toWorld(![Vector](Type-Vector.png "Vector") Localposition)

Transforms from a vector local to E to a world vector (15 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):toLocal(![Vector](Type-Vector.png "Vector") Worldposition)

Transforms from a world vector to a vector local to E (15 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):toWorldAxis(![Vector](Type-Vector.png "Vector") Localaxis)

Transforms an axis local to E to a global axis (15 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):toLocalAxis(![Vector](Type-Vector.png "Vector") Worldaxis)

Transforms a world axis to an axis local to E (15 ops)

### ![Angle](Type-Angle.png "Angle") = ![Entity](Type-Entity.png "Entity"):toWorld(![Angle](Type-Angle.png "Angle") Localangle)

Transforms from an angle local to E to a world angle (15 ops)

### ![Angle](Type-Angle.png "Angle") = ![Entity](Type-Entity.png "Entity"):toLocal(![Angle](Type-Angle.png "Angle") Worldangle)

Transforms from a world angle to an angle local to E (15 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):health()

Gets the health of the entity (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):maxHealth()

Gets the max health of the entity (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):radius()

Gets the size of the object (not precisely, but useful) (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):bearing(![Vector](Type-Vector.png "Vector") Pos)

Gets the bearing from the entity to the vector (15 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):elevation(![Vector](Type-Vector.png "Vector") Pos)

Gets the elevation from the entity to the vector (15 ops)

### ![Angle](Type-Angle.png "Angle") = ![Entity](Type-Entity.png "Entity"):heading(![Vector](Type-Vector.png "Vector") Pos)

Gets the elevation and bearing from the entity to the vector (15 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):mass()

Gets the mass of the entity (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):massCenter()

Gets the Center of Mass of the entity (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):massCenterL()

Gets the center of mass as a local vector (10 ops)

### setMass(![Number](Type-Number.png "Number") Mass)

Sets the mass of the E2 chip (between 0.001 and 50,000) (10 ops)

### ![Entity](Type-Entity.png "Entity"):setMass(![Number](Type-Number.png "Number") Mass)

Sets the mass of the entity (between 0.001 and 50,000) (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):volume()

Gets the volume of the entity (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):surfaceArea()

Gets the surface area of the entity (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):stress()

Gets the stress of the entity (10 ops)

### ![Table](Type-Table.png "Table") = ![Entity](Type-Entity.png "Entity"):frictionSnapshot()

Returns current friction events of the entity as a table of tables [https://wiki.facepunch.com/gmod/PhysObj:GetFrictionSnapshot] (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isPlayer()

Is the entity a player? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isNPC()

Is the entity a NPC? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isNextBot()

Is the entity a NextBot? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isRagdoll()

Is the entity a ragdoll? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isVehicle()

Is the entity a vehicle? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isWorld()

Is the entity the world? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isOnGround()

Is the player/NPC resting on something? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isUnderWater()

Is the entity under water? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isValid()

Returns 1 if the entity is valid, 0 otherwise (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isValidPhysics()

Returns 1 if the entity has valid physics (players don't) (10 ops)

### ![Angle](Type-Angle.png "Angle") = ![Entity](Type-Entity.png "Entity"):angles()

Gets the pitch, yaw and roll of the entity (10 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):getMaterial()

Returns the material of an entity (10 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):getSubMaterial(![Number](Type-Number.png "Number") Index)

 (10 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):getMaterials()

 (20 ops)

### ![Entity](Type-Entity.png "Entity"):setMaterial(![String](Type-String.png "String") Material)

Sets the material of an entity (10 ops)

### ![Entity](Type-Entity.png "Entity"):setSubMaterial(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Material)

 (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getSkin()

Gets Es current skin number (10 ops)

### ![Entity](Type-Entity.png "Entity"):setSkin(![Number](Type-Number.png "Number") Skinindex)

Sets the skin of an entity (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getSkinCount()

Gets Es number of skins (10 ops)

### ![Entity](Type-Entity.png "Entity"):setBodygroup(![Number](Type-Number.png "Number") Bgrp_id, ![Number](Type-Number.png "Number") Bgrp_subid)

Group ID, Group SubID
Sets the bodygroups of the given entity (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getBodygroup(![Number](Type-Number.png "Number") Bgrp_id)

 (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getBodygroups(![Number](Type-Number.png "Number") Bgrp_id)

Group ID
Returns the number of bodygroups in the Group ID of the given entity (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isPlayerHolding()

Is the entity being held by a player? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isOnFire()

Is the entity on fire? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isWeapon()

Is the entity a weapon? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isFrozen()

Is the entity frozen? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isAsleep()

Is the entity asleep? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isGravityEnabled()

Is gravity enabled for the entity? (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isPenetrating()

Is the entity penetrating another entity? (10 ops)

### ![Entity](Type-Entity.png "Entity"):applyForce(![Vector](Type-Vector.png "Vector") Force)

Applies force to the entity according to the given vector's direction and magnitude (30 ops)

### ![Entity](Type-Entity.png "Entity"):applyOffsetForce(![Vector](Type-Vector.png "Vector") Force, ![Vector](Type-Vector.png "Vector") Position)

Applies force to the entity according to the first vector from the location of the second (30 ops)

### ![Entity](Type-Entity.png "Entity"):applyAngForce(![Angle](Type-Angle.png "Angle") Angforce)

Applies torque to the entity according to the given angle (30 ops)

### ![Entity](Type-Entity.png "Entity"):applyTorque(![Vector](Type-Vector.png "Vector") Torque)

Applies torque to the entity according to the given vector, representing the torque axis, magnitude and direction (30 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):inertia()

Gets the principal components of the entity's inertia tensor in the form ( Ixx, Iyy, Izz ) (30 ops)

### ![Entity](Type-Entity.png "Entity"):lockPod(![Number](Type-Number.png "Number") Lock)

1 locks and 0 unlocks the vehicle (10 ops)

### ![Entity](Type-Entity.png "Entity"):killPod()

Kills player in vehicle (10 ops)

### ![Entity](Type-Entity.png "Entity"):ejectPod()

Ejects player in vehicle (10 ops)

### ![Entity](Type-Entity.png "Entity"):podStripWeapons()

Strips player in vehicle (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):boxSize()

Gets the dimensions of the entity's bounding box as a vector (length, width, height) (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):boxCenter()

Gets the center of the entity's bounding box, as a local position vector (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):boxCenterW()

Same as using E:toWorld(E:boxCenter()), but since Lua is faster, this is more efficient (also shorter to write) (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):boxMax()

Gets the maximum local XYZ of the entity's bounding box (the "highest" corner), as a local position vector (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):boxMin()

Gets the minimum local XYZ of the entity's bounding box (the "lowest" corner), as a local position vector (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):aabbMin()

Returns the entity's (min) axis-aligned bounding box (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):aabbMax()

Returns the entity's (max) axis-aligned bounding box (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):aabbSize()

Returns the entity's axis-aligned bounding box size (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):aabbWorldMin()

Returns the rotated entity's min world-axis-aligned bounding box corner (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):aabbWorldMax()

Returns the rotated entity's max world-axis-aligned bounding box corner (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):aabbWorldSize()

Returns the rotated entity's world-axis-aligned bounding box size (10 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):driver()

Returns the driver of the vehicle if there is one, nil otherwise (5 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):passenger()

Returns the passenger of the vehicle if there is one, in single seat pods this will return the driver (5 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):toString()

Converts entity to string (5 ops)

### ![String](Type-String.png "String") = toString(![Entity](Type-Entity.png "Entity") Ent)

Converts entity to string (5 ops)

### ![Entity](Type-Entity.png "Entity"):removeTrails()

Removes the trail from E (50 ops)

### ![Entity](Type-Entity.png "Entity"):setTrails(![Number](Type-Number.png "Number") Startsize, ![Number](Type-Number.png "Number") Endsize, ![Number](Type-Number.png "Number") Length, ![String](Type-String.png "String") Material, ![Vector](Type-Vector.png "Vector") Color, ![Number](Type-Number.png "Number") Alpha)

StartSize, EndSize, Length, Material, Color (RGB), Alpha. Sets entity's trails with the specified attributes (75 ops)

### ![Entity](Type-Entity.png "Entity"):setTrails(![Number](Type-Number.png "Number") Startsize, ![Number](Type-Number.png "Number") Endsize, ![Number](Type-Number.png "Number") Length, ![String](Type-String.png "String") Material, ![Vector4](Type-Vector4.png "Vector4") Color)

StartSize, EndSize, Length, Material, Color (RGBA). Sets entity's trails with the specified attributes (75 ops)

### ![Entity](Type-Entity.png "Entity"):setTrails(![Number](Type-Number.png "Number") Startsize, ![Number](Type-Number.png "Number") Endsize, ![Number](Type-Number.png "Number") Length, ![String](Type-String.png "String") Material)

StartSize, EndSize, Length, Material. Sets entity's trails with the specified attributes (75 ops)

### ![Entity](Type-Entity.png "Entity"):setTrails(![Number](Type-Number.png "Number") Startsize, ![Number](Type-Number.png "Number") Endsize, ![Number](Type-Number.png "Number") Length, ![String](Type-String.png "String") Material, ![Vector](Type-Vector.png "Vector") Color, ![Number](Type-Number.png "Number") Alpha, ![Number](Type-Number.png "Number") Attachmentid, ![Number](Type-Number.png "Number") Additive)

StartSize, EndSize, Length, Material, Color (RGB), Alpha, AttachmentID, Additive. Sets entity's trails with the specified attributes (75 ops)

### ![Number](Type-Number.png "Number") = trailsLeft()

Returns how many more entities can have trails (2 ops)

### ![Number](Type-Number.png "Number") = trailsCount()

Returns how many entities currently have trails (2 ops)

### ![Number](Type-Number.png "Number") = trailsMax()

Returns the maximum amount of entities that can have trails at the same time (Beware, the limit is shared between different chips!) (1 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):lookupAttachment(![String](Type-String.png "String") Attachmentname)

Returns Es attachment ID associated with attachmentName (15 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):attachmentPos(![Number](Type-Number.png "Number") Attachmentid)

Returns Es attachment position associated with attachmentID (15 ops)

### ![Angle](Type-Angle.png "Angle") = ![Entity](Type-Entity.png "Entity"):attachmentAng(![Number](Type-Number.png "Number") Attachmentid)

Returns Es attachment angle associated with attachmentID (15 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):attachmentPos(![String](Type-String.png "String") Attachmentname)

Same as E:attachmentPos(E:lookupAttachment(attachmentName)) (15 ops)

### ![Angle](Type-Angle.png "Angle") = ![Entity](Type-Entity.png "Entity"):attachmentAng(![String](Type-String.png "String") Attachmentname)

Same as E:attachmentAng(E:lookupAttachment(attachmentName)) (15 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):attachments()

Returns array of attachment names of the entity (20 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):nearestPoint(![Vector](Type-Vector.png "Vector") Point)

Returns the closest point on the edge of the entity's bounding box to the given vector (15 ops)

### ![Entity](Type-Entity.png "Entity"):ignite()

Ignites an entity for 360 seconds (same as C menu). Requires wire_expression2_entity_ignite_enabled (15 ops)

### ![Entity](Type-Entity.png "Entity"):ignite(![Number](Type-Number.png "Number") Length)

Ignites an entity for the given length in seconds. Requires wire_expression2_entity_ignite_enabled (15 ops)

### ![Entity](Type-Entity.png "Entity"):ignite(![Number](Type-Number.png "Number") Length, ![Number](Type-Number.png "Number") Radius)

Creates a fire at an entity with given radius and length in seconds. Requires wire_expression2_entity_ignite_enabled (15 ops)

### ![Entity](Type-Entity.png "Entity"):extinguish()

Extinguishes an entity granted you have permission. Does not work inside of entityDamage event if the attacker is the fire itself (15 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getCollisionGroup()

Returns the collision group of the entity (15 ops)

### ![Entity](Type-Entity.png "Entity"):setCollisionGroup(![Number](Type-Number.png "Number") Group)

Sets the collision group of the entity. Does not work on players. Use one of the _COLLISION_GROUP constants (15 ops)

### ![Entity](Type-Entity.png "Entity"):noCollideAll(![Number](Type-Number.png "Number") State)

 (15 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):getFlexBounds(![Number](Type-Number.png "Number") Flex)

 (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getFlexCount()

Gets the number of flexes on the entity (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getFlexID(![String](Type-String.png "String") Flex)

Gets the flex ID of the given name or -1 if it doesn't exist (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getFlexScale()

Gets the flex scale of the entity (5 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):getFlexName(![Number](Type-Number.png "Number") Id)

Gets the name of the flex (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getFlexWeight(![Number](Type-Number.png "Number") Flex)

 (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):hasFlexes()

Returns 1 if the entity has flexes (5 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):getFlexBounds(![String](Type-String.png "String") Flex)

 (15 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getFlexWeight(![String](Type-String.png "String") Flex)

 (15 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):getFlexes()

Gets a 0-indexed array of all flexes and their names (50 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getModelBoneCount()

Gets the number of bones on the entity's model. Note these are different from E2 bones (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getModelBoneIndex(![String](Type-String.png "String") Bone_name)

Gets the bone index of the given name or -1 if it doesn't exist (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getModelBoneName(![Number](Type-Number.png "Number") Bone_index)

Gets the name of the bone (5 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):getModelBones()

Gets a 0-indexed array of all bones and their names. Note these are different from E2 bones (50 ops)
