[Jump to table of contents](#default-extensions)

# Custom/prop

### ![Entity](Type-Entity.png "Entity") = propSpawn(![String](Type-String.png "String") Model, ![Number](Type-Number.png "Number") Frozen)

Use the model string or a template entity to spawn a prop. You can set the position and/or the rotation as well. The last number indicates frozen/unfrozen. (40 ops)

### ![Entity](Type-Entity.png "Entity") = propSpawn(![Entity](Type-Entity.png "Entity") Template, ![Number](Type-Number.png "Number") Frozen)

Entity template, Frozen Spawns a prop with the model of the template entity. If frozen is 0, then it will spawn unfrozen. (40 ops)

### ![Entity](Type-Entity.png "Entity") = propSpawn(![String](Type-String.png "String") Model, ![Vector](Type-Vector.png "Vector") Pos, ![Number](Type-Number.png "Number") Frozen)

Model path, Position, Frozen Spawns a prop with the model denoted by the string filepath at the position denoted by the vector. If frozen is 0, then it will spawn unfrozen. (40 ops)

### ![Entity](Type-Entity.png "Entity") = propSpawn(![Entity](Type-Entity.png "Entity") Template, ![Vector](Type-Vector.png "Vector") Pos, ![Number](Type-Number.png "Number") Frozen)

Entity template, Position, Frozen Spawns a prop with the model of the template entity at the position denoted by the vector. If frozen is 0, then it will spawn unfrozen. (40 ops)

### ![Entity](Type-Entity.png "Entity") = propSpawn(![String](Type-String.png "String") Model, ![Angle](Type-Angle.png "Angle") Rot, ![Number](Type-Number.png "Number") Frozen)

Model path, Rotation, Frozen Spawns a prop with the model denoted by the string filepath and rotated to the angle given. If frozen is 0, then it will spawn unfrozen. (40 ops)

### ![Entity](Type-Entity.png "Entity") = propSpawn(![Entity](Type-Entity.png "Entity") Template, ![Angle](Type-Angle.png "Angle") Rot, ![Number](Type-Number.png "Number") Frozen)

Rotation, Frozen Spawns a prop with the model of the template entity and rotated to the angle given. If frozen is 0, then it will spawn unfrozen. (40 ops)

### ![Entity](Type-Entity.png "Entity") = propSpawn(![String](Type-String.png "String") Model, ![Vector](Type-Vector.png "Vector") Pos, ![Angle](Type-Angle.png "Angle") Rot, ![Number](Type-Number.png "Number") Frozen)

Model path, Position, Rotation, Frozen Spawns a prop with the model denoted by the string file path, at the position denoted by the vector, and rotated to the angle given. If frozen is 0, then it will spawn unfrozen. (40 ops)

### ![Entity](Type-Entity.png "Entity") = propSpawn(![Entity](Type-Entity.png "Entity") Template, ![Vector](Type-Vector.png "Vector") Pos, ![Angle](Type-Angle.png "Angle") Rot, ![Number](Type-Number.png "Number") Frozen)

Position, Rotation, Frozen Spawns a prop with the model of the template entity, at the position denoted by the vector, and rotated to the angle given. If frozen is 0, then it will spawn unfrozen. (40 ops)

### ![Entity](Type-Entity.png "Entity") = sentSpawn(![String](Type-String.png "String") Class)

Sent class - Spawns a SENT with no parameters. (Attempts to default the required values). (Requires wire_expression2_propcore_sents_whitelist 0 to spawn sents from entity tab!) (150 ops)

### ![Entity](Type-Entity.png "Entity") = sentSpawn(![String](Type-String.png "String") Class, ![Vector](Type-Vector.png "Vector") Pos)

Sent class, Position - Spawns a SENT with no parameters. (Attempts to default the required values). (Requires wire_expression2_propcore_sents_whitelist 0 to spawn sents from entity tab!) (150 ops)

### ![Entity](Type-Entity.png "Entity") = sentSpawn(![String](Type-String.png "String") Class, ![Table](Type-Table.png "Table") Data)

Sent class, Sent data - Spawns a SENT with provided data as parameters. (Requires wire_expression2_propcore_sents_whitelist 0 to spawn sents from entity tab!) (150 ops)

### ![Entity](Type-Entity.png "Entity") = sentSpawn(![String](Type-String.png "String") Class, ![Vector](Type-Vector.png "Vector") Pos, ![Table](Type-Table.png "Table") Data)

 (150 ops)

### ![Entity](Type-Entity.png "Entity") = sentSpawn(![String](Type-String.png "String") Class, ![Vector](Type-Vector.png "Vector") Pos, ![Angle](Type-Angle.png "Angle") Rot)

Sent class, Position, Rotation - Spawns a SENT with no parameters. (Attempts to default the required values). (Requires wire_expression2_propcore_sents_whitelist 0 to spawn sents from entity tab!) (150 ops)

### ![Entity](Type-Entity.png "Entity") = sentSpawn(![String](Type-String.png "String") Class, ![Vector](Type-Vector.png "Vector") Pos, ![Angle](Type-Angle.png "Angle") Rot, ![Table](Type-Table.png "Table") Data)

Sent class, Position, Rotation, Sent data - Spawns a SENT with provided data as parameters. (Requires wire_expression2_propcore_sents_whitelist 0 to spawn sents from entity tab!) (150 ops)

### ![Entity](Type-Entity.png "Entity") = sentSpawn(![String](Type-String.png "String") Class, ![Vector](Type-Vector.png "Vector") Pos, ![Angle](Type-Angle.png "Angle") Rot, ![Number](Type-Number.png "Number") Frozen)

Sent class, Position, Rotation, Frozen - Spawns a SENT with no parameters. (Attempts to default the required values). (Requires wire_expression2_propcore_sents_whitelist 0 to spawn sents from entity tab!) (150 ops)

### ![Entity](Type-Entity.png "Entity") = sentSpawn(![String](Type-String.png "String") Class, ![Vector](Type-Vector.png "Vector") Pos, ![Angle](Type-Angle.png "Angle") Rot, ![Number](Type-Number.png "Number") Frozen, ![Table](Type-Table.png "Table") Data)

Sent class, Position, Rotation, Frozen, Sent data - Spawns a SENT with provided data as parameters. (Requires wire_expression2_propcore_sents_whitelist 0 to spawn sents from entity tab!) (150 ops)

### ![Array](Type-Array.png "Array") = sentGetWhitelisted()

Returns an array of classes, which is registered to the whitelist (can be spawned regardless of wire_expression2_propcore_sents_whitelist). (Can be used to make a lookup table) (25 ops)

### ![Table](Type-Table.png "Table") = sentGetData(![String](Type-String.png "String") Class)

Returns a table, where keys are parameter names (key sensitive!) and values as a table, where 'type' is a value type, 'default_value' is the default value that will be used, if none provided, and 'description' is a description of the parameter. (30 ops)

### ![Table](Type-Table.png "Table") = sentGetData(![String](Type-String.png "String") Class, ![String](Type-String.png "String") Key)

Returns a table, where 'type' is a value type, 'default_value' is the default value that will be used, if none provided, and 'description' is a description of the parameter. (10 ops)

### ![Table](Type-Table.png "Table") = sentGetDataTypes(![String](Type-String.png "String") Class)

Returns a table, where keys are parameter names (key sensitive!) and values is (lua-)types. (25 ops)

### ![String](Type-String.png "String") = sentGetDataType(![String](Type-String.png "String") Class, ![String](Type-String.png "String") Key)

Returns parameters's (lua-)type of the parameter. (5 ops)

### ![Table](Type-Table.png "Table") = sentGetDataDefaultValues(![String](Type-String.png "String") Class)

Returns a table, where keys are parameter names (key sensitive!) and values is default values, which will be applied if none would be provided. (25 ops)

### ![String](Type-String.png "String") = sentGetDataDefaultValue(![String](Type-String.png "String") Class, ![String](Type-String.png "String") Key)

 (5 ops)

### ![Table](Type-Table.png "Table") = sentGetDataDescriptions(![String](Type-String.png "String") Class)

Returns a table, where keys are parameter names (key sensitive!) and values is descriptions of the parameter. (25 ops)

### ![String](Type-String.png "String") = sentGetDataDescription(![String](Type-String.png "String") Class, ![String](Type-String.png "String") Key)

 (5 ops)

### ![Number](Type-Number.png "Number") = sentCanCreate()

Returns 1 if you can spawn a SENT, 0 otherwise. (Complete alias of propCanCreate()) (5 ops)

### ![Number](Type-Number.png "Number") = sentCanCreate(![String](Type-String.png "String") Class)

Returns 1 if you can spawn a provided class(type) SENT, 0 otherwise. (Accounts both for antispam and whitelist) (5 ops)

### ![Number](Type-Number.png "Number") = sentIsWhitelist()

Returns 1 if the whitelist is enabled, 0 otherwise. (1 ops)

### ![Number](Type-Number.png "Number") = sentIsEnabled()

Returns 1 if server allows spawning sents, 0 otherwise. (1 ops)

### ![Entity](Type-Entity.png "Entity") = seatSpawn(![String](Type-String.png "String") Model, ![Number](Type-Number.png "Number") Frozen)

Model path, Frozen Spawns a prop with the model denoted by the string filepath. If frozen is 0, then it will spawn unfrozen. (50 ops)

### ![Entity](Type-Entity.png "Entity") = seatSpawn(![String](Type-String.png "String") Model, ![Vector](Type-Vector.png "Vector") Pos, ![Angle](Type-Angle.png "Angle") Rot, ![Number](Type-Number.png "Number") Frozen)

Model path, Frozen Spawns a prop with the model denoted by the string filepath. If frozen is 0, then it will spawn unfrozen. (50 ops)

### ![Entity](Type-Entity.png "Entity") = seatSpawn(![String](Type-String.png "String") Model, ![Vector](Type-Vector.png "Vector") Pos, ![Angle](Type-Angle.png "Angle") Rot, ![Number](Type-Number.png "Number") Frozen, ![String](Type-String.png "String") Vehicletype)

Model path, Frozen Spawns a prop with the model denoted by the string filepath. If frozen is 0, then it will spawn unfrozen. String seatType, determines what animations the seat will have. For example phx_seat2 and phx_seat3 will have Jeep and Airboat animations. (50 ops)

### ![Entity](Type-Entity.png "Entity"):propDelete()

Deletes the specified prop. (10 ops)

### ![Entity](Type-Entity.png "Entity"):propBreak()

Breaks/Explodes breakable/explodable props (Useful for Mines). (10 ops)

### ![Entity](Type-Entity.png "Entity"):propDissolve()

Dissolves the specified entity. (10 ops)

### ![Entity](Type-Entity.png "Entity"):propDissolve(![Number](Type-Number.png "Number") Dissolvetype)

Dissolves the specified entity using the given dissolve type (_ENTITY_DISSOLVE). (10 ops)

### ![Entity](Type-Entity.png "Entity"):propDissolve(![Number](Type-Number.png "Number") Dissolvetype, ![Number](Type-Number.png "Number") Magnitude)

Dissolves the specified entity with the given dissolve type (_ENTITY_DISSOLVE) and magnitude. (10 ops)

### ![Entity](Type-Entity.png "Entity"):use()

Simulates a player pressing their use key on the entity. (10 ops)

### ![Number](Type-Number.png "Number") = ![Table](Type-Table.png "Table"):propDelete()

Deletes all the props in the given table, returns the amount of props deleted. (30 ops)

### ![Number](Type-Number.png "Number") = ![Array](Type-Array.png "Array"):propDelete()

Deletes all the props in the given array, returns the amount of props deleted. (30 ops)

### propDeleteAll()

Removes all entities spawned by this E2 (30 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):propIsDupeable()

 (1 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):propCanSetDupeable()

 (1 ops)

### ![Entity](Type-Entity.png "Entity"):propNoDupe(![Number](Type-Number.png "Number") Nodupe)

 (2 ops)

### ![Entity](Type-Entity.png "Entity"):propManipulate(![Vector](Type-Vector.png "Vector") Pos, ![Angle](Type-Angle.png "Angle") Rot, ![Number](Type-Number.png "Number") Freeze, ![Number](Type-Number.png "Number") Gravity, ![Number](Type-Number.png "Number") Notsolid)

Allows to do any single prop core function in one term (position, rotation, freeze, gravity, notsolid) (10 ops)

### ![Entity](Type-Entity.png "Entity"):propFreeze(![Number](Type-Number.png "Number") Freeze)

Passing 0 unfreezes the entity, everything else freezes it. (10 ops)

### ![Entity](Type-Entity.png "Entity"):propNotSolid(![Number](Type-Number.png "Number") Notsolid)

Passing 0 makes the entity solid, everything else makes it non-solid. (10 ops)

### ![Entity](Type-Entity.png "Entity"):propDraw(![Number](Type-Number.png "Number") Drawenable)

Passing 0 disables rendering for the entity (makes it really invisible) (10 ops)

### ![Entity](Type-Entity.png "Entity"):propShadow(![Number](Type-Number.png "Number") Shadowenable)

Passing 0 disables rendering for the entity's shadow (10 ops)

### ![Entity](Type-Entity.png "Entity"):propSleep(![Number](Type-Number.png "Number") Sleep)

Puts an entity to 'sleep', causing it to stop moving until any physical interaction occurs. (10 ops)

### ![Entity](Type-Entity.png "Entity"):propGravity(![Number](Type-Number.png "Number") Gravity)

Passing 0 makes the entity weightless, everything else makes it weighty. (10 ops)

### ![Entity](Type-Entity.png "Entity"):propDrag(![Number](Type-Number.png "Number") Drag)

Passing 0 makes the entity not be affected by drag (10 ops)

### ![Entity](Type-Entity.png "Entity"):propInertia(![Vector](Type-Vector.png "Vector") Inertia)

Sets the directional inertia (10 ops)

### ![Entity](Type-Entity.png "Entity"):propSetBuoyancy(![Number](Type-Number.png "Number") Buoyancy)

Sets the prop's buoyancy ratio from 0 to 1 (10 ops)

### ![Entity](Type-Entity.png "Entity"):propSetFriction(![Number](Type-Number.png "Number") Friction)

Sets prop's friction coefficient (default is 1) (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):propGetFriction()

Gets prop's friction coefficient (10 ops)

### ![Entity](Type-Entity.png "Entity"):propSetElasticity(![Number](Type-Number.png "Number") Elasticity)

Sets prop's elasticity coefficient (default is 1) (10 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):propGetElasticity()

Gets prop's elasticity coefficient (10 ops)

### ![Entity](Type-Entity.png "Entity"):propMakePersistent(![Number](Type-Number.png "Number") Persistent)

Setting to 1 will make the prop persistent. (10 ops)

### ![Entity](Type-Entity.png "Entity"):propPhysicalMaterial(![String](Type-String.png "String") Physprop)

Changes the surface material of a prop (eg. wood, metal, ... See Material_surface_properties ). (10 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):propPhysicalMaterial()

Returns the surface material of a prop. (10 ops)

### ![Entity](Type-Entity.png "Entity"):propSetVelocity(![Vector](Type-Vector.png "Vector") Velocity)

Sets the velocity of the prop for the next iteration (10 ops)

### ![Entity](Type-Entity.png "Entity"):propSetVelocityInstant(![Vector](Type-Vector.png "Vector") Velocity)

Sets the initial velocity of the prop (10 ops)

### ![Entity](Type-Entity.png "Entity"):propSetAngVelocity(![Vector](Type-Vector.png "Vector") Velocity)

Sets the angular velocity of the prop for the next iteration (10 ops)

### ![Entity](Type-Entity.png "Entity"):propSetAngVelocityInstant(![Vector](Type-Vector.png "Vector") Velocity)

Sets the initial angular velocity of the prop (10 ops)

### ![Entity](Type-Entity.png "Entity"):propStatic(![Number](Type-Number.png "Number") Static)

Sets to 1 to make the entity static (disables movement, physgun, unfreeze, drive...) or 0 to cancel. (10 ops)

### ![Bone](Type-Bone.png "Bone"):boneManipulate(![Vector](Type-Vector.png "Vector") Pos, ![Angle](Type-Angle.png "Angle") Rot, ![Number](Type-Number.png "Number") Isfrozen, ![Number](Type-Number.png "Number") Gravity, ![Number](Type-Number.png "Number") Collision)

Allows to do any single bone function in one term (position, rotation, freeze, gravity, collision) (10 ops)

### ![Bone](Type-Bone.png "Bone"):boneFreeze(![Number](Type-Number.png "Number") Isfrozen)

Passing 0 unfreezes that specific bone, everything else freezes it. (10 ops)

### ![Bone](Type-Bone.png "Bone"):setCollisions(![Number](Type-Number.png "Number") Enable)

Passing 0 will disable collisions with the everything but players (30 ops)

### ![Bone](Type-Bone.png "Bone"):setDrag(![Number](Type-Number.png "Number") Drag)

Passing 0 makes the bone not be affected by drag (30 ops)

### ![Bone](Type-Bone.png "Bone"):setInertia(![Vector](Type-Vector.png "Vector") Inertia)

Sets the directional inertia (30 ops)

### ![Bone](Type-Bone.png "Bone"):setBuoyancy(![Number](Type-Number.png "Number") Buoyancy)

 (30 ops)

### ![Bone](Type-Bone.png "Bone"):setPhysicalMaterial(![String](Type-String.png "String") Material)

Sets the surface material of the bone. (eg. wood, metal, ... See Material_surface_properties ) (30 ops)

### ![Bone](Type-Bone.png "Bone"):setVelocity(![Vector](Type-Vector.png "Vector") Velocity)

Sets the velocity of the bone for the next iteration (30 ops)

### ![Bone](Type-Bone.png "Bone"):setVelocityInstant(![Vector](Type-Vector.png "Vector") Velocity)

Sets the initial velocity of the bone (30 ops)

### ![Bone](Type-Bone.png "Bone"):setAngVelocity(![Vector](Type-Vector.png "Vector") Velocity)

Sets the angular velocity of the bone for the next iteration (30 ops)

### ![Bone](Type-Bone.png "Bone"):setAngVelocityInstant(![Vector](Type-Vector.png "Vector") Velocity)

Sets the initial angular velocity of the bone (30 ops)

### ![Entity](Type-Entity.png "Entity"):makeStatue(![Number](Type-Number.png "Number") Enable)

Applies the 'statue' effect on a ragdoll. Remove it by passing 0. (5000 ops)

### ![Entity](Type-Entity.png "Entity"):setPos(![Vector](Type-Vector.png "Vector") Pos)

Sets the position of an entity. (20 ops)

### ![Entity](Type-Entity.png "Entity"):reposition(![Vector](Type-Vector.png "Vector") Pos)

Deprecated. Kept for backwards-compatibility. (20 ops)

### ![Entity](Type-Entity.png "Entity"):setLocalPos(![Vector](Type-Vector.png "Vector") Pos)

Sets the position of an entity local to its parent. (20 ops)

### ![Entity](Type-Entity.png "Entity"):rerotate(![Angle](Type-Angle.png "Angle") Rot)

Deprecated. Kept for backwards-compatibility. (20 ops)

### ![Entity](Type-Entity.png "Entity"):setAng(![Angle](Type-Angle.png "Angle") Rot)

Set the rotation of an entity. (20 ops)

### ![Entity](Type-Entity.png "Entity"):setLocalAng(![Angle](Type-Angle.png "Angle") Rot)

Set the rotation of an entity local to its parent. (20 ops)

### ![Bone](Type-Bone.png "Bone"):setPos(![Vector](Type-Vector.png "Vector") Pos)

Sets the position of a bone. (20 ops)

### ![Bone](Type-Bone.png "Bone"):setAng(![Angle](Type-Angle.png "Angle") Rot)

Set the rotation of a bone. (20 ops)

### ![Entity](Type-Entity.png "Entity"):ragdollFreeze(![Number](Type-Number.png "Number") Isfrozen)

Passing 0 unfreezes the entire ragdoll. (60 ops)

### ![Angle](Type-Angle.png "Angle") = ![Entity](Type-Entity.png "Entity"):ragdollGetAng()

 (5 ops)

### ![Entity](Type-Entity.png "Entity"):ragdollSetPos(![Vector](Type-Vector.png "Vector") Pos)

Sets the position of a ragdoll while preserving pose. (150 ops)

### ![Entity](Type-Entity.png "Entity"):ragdollSetAng(![Angle](Type-Angle.png "Angle") Rot)

Set the rotation of a ragdoll while preserving pose. (150 ops)

### ![Table](Type-Table.png "Table") = ![Entity](Type-Entity.png "Entity"):ragdollGetPose()

Gets a specially built table containing the pose of the ragdoll. See ragdollSetPose. (150 ops)

### ![Entity](Type-Entity.png "Entity"):ragdollSetPose(![Table](Type-Table.png "Table") Pose, ![Number](Type-Number.png "Number") Rotate)

Sets the pose of a ragdoll while preserving position. Setting rotate to 0 makes the ragdoll use the pose's original angle. See ragdollGetPose. (150 ops)

### ![Entity](Type-Entity.png "Entity"):ragdollSetPose(![Table](Type-Table.png "Table") Pose)

Sets the pose of a ragdoll while preserving position and angle. See ragdollGetPose. (150 ops)

### ![Entity](Type-Entity.png "Entity"):parentTo(![Entity](Type-Entity.png "Entity") Target)

Parents one entity to another. (20 ops)

### ![Entity](Type-Entity.png "Entity"):parentToAttachment(![Entity](Type-Entity.png "Entity") Target, ![String](Type-String.png "String") Attachmentname)

Parents one entity to anothers attachment. (20 ops)

### ![Entity](Type-Entity.png "Entity"):deparent()

Unparents an entity, so it moves freely again. (5 ops)

### ![Entity](Type-Entity.png "Entity"):parentTo()

Parents one entity to another. (5 ops)

### propSpawnEffect(![Number](Type-Number.png "Number") On)

Set to 1 to enable prop spawn effect, 0 to disable. (1 ops)

### propSpawnUndo(![Number](Type-Number.png "Number") On)

Set to 0 to force prop removal on E2 shutdown, and suppress Undo entries for props. (1 ops)

### ![Number](Type-Number.png "Number") = propCanCreate()

Returns 1 when propSpawn() will successfully spawn a prop until the limit is reached. (1 ops)

### ![Entity](Type-Entity.png "Entity"):setEyeTarget(![Vector](Type-Vector.png "Vector") Pos)

For NPCs, sets the eye target to the world position. For ragdolls, sets the eye target to the local eye position (10 ops)

### ![Entity](Type-Entity.png "Entity"):setFlexWeight(![Number](Type-Number.png "Number") Flex, ![Number](Type-Number.png "Number") Weight)

 (10 ops)

### ![Entity](Type-Entity.png "Entity"):setEyeTargetLocal(![Vector](Type-Vector.png "Vector") Pos)

Sets the eye target to the local eye position (30 ops)

### ![Entity](Type-Entity.png "Entity"):setEyeTargetWorld(![Vector](Type-Vector.png "Vector") Pos)

Sets the eye target to the world position (30 ops)

### ![Entity](Type-Entity.png "Entity"):setFlexWeight(![String](Type-String.png "String") Flex, ![Number](Type-Number.png "Number") Weight)

 (20 ops)

### ![Entity](Type-Entity.png "Entity"):setFlexScale(![Number](Type-Number.png "Number") Scale)

Sets the flex scale of the entity (20 ops)

### ![Table](Type-Table.png "Table") = Collision:toTable()

 (20 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:hitPos()

Returns a vector of where the collision ocurred (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:pos()

Returns a vector of where the collision ocurred
Alias of hitPos(xcd:) (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:position()

Returns a vector of where the collision ocurred
Alias of hitPos(xcd:) (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:ourOldVelocity()

Returns a vector of the velocity of the tracked entity before the collision occurred. (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:entityOldVelocity()

Returns a vector of the velocity of the tracked entity before the collision occurred.
Alias of ourOldVelocity(xcd:) (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:theirOldVelocity()

Returns a vector of the velocity of the hit entity before the collision occurred (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:hitEntityOldVelocity()

Returns a vector of the velocity of the hit entity before the collision occurred
Alias of theirOldVelocity(xcd:) (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:hitNormal()

Returns the hitnormal(vector) of the surface on the tracked entity that hit the other entity (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:hitSpeed()

Returns a vector of the speed the impact occurred with (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:ourNewVelocity()

Returns a vector of the velocity of the tracked entity after the collision occurred. (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:entityNewVelocity()

Returns a vector of the velocity of the tracked entity after the collision occurred.
Alias of ourNewVelocity(xcd:) (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:theirNewVelocity()

Returns a vector of the velocity of the hit entity after the collision occurred. (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:hitEntityNewVelocity()

Returns a vector of the velocity of the hit entity after the collision occurred.
Alias of theirNewVelocity(xcd:) (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:ourOldAngularVelocity()

Returns a vector of the angular velocity of the tracked entity before the collision occurred. (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:entityOldAngularVelocity()

Returns a vector of the angular velocity of the tracked entity before the collision occurred.
Alias of ourOldAngularVelocity(xcd:) (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:theirOldAngularVelocity()

Returns a vector of the angular velocity of the hit entity before the collision occurred. (5 ops)

### ![Vector](Type-Vector.png "Vector") = Collision:hitEntityOldAngularVelocity()

Returns a vector of the angular velocity of the hit entity before the collision occurred.
Alias of ourOldAngularVelocity(xcd:) (5 ops)

### ![Number](Type-Number.png "Number") = Collision:speed()

Returns a number representing the speed at which the collision occurred. (2 ops)

### ![Number](Type-Number.png "Number") = Collision:ourSurfaceProps()

Returns a number representing the surface properties of the tracked entity (2 ops)

### ![Number](Type-Number.png "Number") = Collision:entitySurfaceProps()

Returns a number representing the surface properties of the tracked entity
Alias of ourSurfaceProps(xcd:) (2 ops)

### ![Number](Type-Number.png "Number") = Collision:theirSurfaceProps()

Returns a number representing the surface properties of the hit entity (2 ops)

### ![Number](Type-Number.png "Number") = Collision:hitEntitySurfaceProps()

Returns a number representing the surface properties of the hit entity
Alias of theirSurfaceProps(xcd:) (2 ops)

### ![Number](Type-Number.png "Number") = Collision:deltaTime()

Returns a number representing how long ago the last collision between the tracked entity and the hit entity was, in seconds.
Capped at 1 second. (2 ops)

### ![Entity](Type-Entity.png "Entity") = Collision:hitEntity()

Returns the entity that was hit for this collision. (2 ops)

### ![Number](Type-Number.png "Number") = trackCollision(![Entity](Type-Entity.png "Entity") Ent)

Starts tracking collisions for the entity, will fire event entityCollision when they occur. Does not track when players or vehicles hit world, only other entities.
Needs event entityCollision(entity, entity, collision) in order to run.
Returns 1 on success or 0 on error in non-strict (20 ops)

### ![Number](Type-Number.png "Number") = trackCollision(![Entity](Type-Entity.png "Entity") Ent, Function Cb)

Starts tracking collisions for the entity, will call the provided function, then fire event entityCollision when they occur.
May track without event entityCollision. Passed callback function needs argument signature of (eexcd), aka (entity, entity, collision)
For more info see trackCollision(e) (20 ops)

### ![Number](Type-Number.png "Number") = isTrackingCollision(![Entity](Type-Entity.png "Entity") Ent)

Returns 1 if the entity's collisions are already being tracked, 0 if not. Errors on an invalid ent (5 ops)

### stopTrackingCollision(![Entity](Type-Entity.png "Entity") Ent)

Stops tracking collisions for the entity.
Error in strict if entity is invalid or entity isn't being tracked (5 ops)
