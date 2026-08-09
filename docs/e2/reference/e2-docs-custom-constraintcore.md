[Jump to table of contents](#default-extensions)

# Custom/constraintcore

### enableConstraintUndo(![Number](Type-Number.png "Number") State)

 (1 ops)

### axis(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2)

Creates an axis constraint between two entities at vectors local to each entity (30 ops)

### axis(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Friction)

Creates an axis constraint between two entities at vectors local to each entity with friction (30 ops)

### axis(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Friction, ![Vector](Type-Vector.png "Vector") Localaxis)

Creates an axis constraint between two entities at vectors local to each entity with friction and local rotation axis (30 ops)

### ballsocket(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V, ![Entity](Type-Entity.png "Entity") Ent2)

 (30 ops)

### ballsocket(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V, ![Entity](Type-Entity.png "Entity") Ent2, ![Number](Type-Number.png "Number") Friction)

 (30 ops)

### ballsocket(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") Mins, ![Vector](Type-Vector.png "Vector") Maxs, ![Vector](Type-Vector.png "Vector") Frictions)

Creates an AdvBallsocket constraint between two entities at a vector local to ent1, using the specified mins, maxs, and frictions (30 ops)

### ballsocket(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") Mins, ![Vector](Type-Vector.png "Vector") Maxs, ![Vector](Type-Vector.png "Vector") Frictions, ![Number](Type-Number.png "Number") Rotateonly)

Creates an AdvBallsocket constraint between two entities at a vector local to ent1, using the specified mins, maxs, frictions, rotateonly (30 ops)

### weldAng(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V, ![Entity](Type-Entity.png "Entity") Ent2)

 (30 ops)

### hydraulic(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Width)

Creates a hydraulic constraint with a referenceid, between an entity and a bone, at vectors local to each (30 ops)

### hydraulic(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Constant, ![Number](Type-Number.png "Number") Damping, ![Number](Type-Number.png "Number") Rdamping, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Width, ![Number](Type-Number.png "Number") Stretch)

Creates a hydraulic constraint with a referenceid, between and entity and a bone, at vectors local to each, with constant, damping, relative damping material, width, and stretch only (30 ops)

### hydraulic(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Constant, ![Number](Type-Number.png "Number") Damping, ![Number](Type-Number.png "Number") Rdamping, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Width, ![Number](Type-Number.png "Number") Stretch, ![Vector](Type-Vector.png "Vector") Color)

Creates a hydraulic constraint with a referenceid, between an entity and a bone, at vectors local to each, with constant, damping, relative damping, material, width, stretch only, and color (30 ops)

### hydraulic(![Number](Type-Number.png "Number") Index, ![Bone](Type-Bone.png "Bone") Bone1, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Width)

Creates a hydraulic constraint with a referenceid, between two bones, at vectors local to each (30 ops)

### hydraulic(![Number](Type-Number.png "Number") Index, ![Bone](Type-Bone.png "Bone") Bone1, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Constant, ![Number](Type-Number.png "Number") Damping, ![Number](Type-Number.png "Number") Rdamping, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Width, ![Number](Type-Number.png "Number") Stretch)

Creates a hydraulic constraint with a referenceid, between two bones, at vectors local to each, with constant, damping, relative damping material, width, and stretch only (30 ops)

### hydraulic(![Number](Type-Number.png "Number") Index, ![Bone](Type-Bone.png "Bone") Bone1, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Constant, ![Number](Type-Number.png "Number") Damping, ![Number](Type-Number.png "Number") Rdamping, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Width, ![Number](Type-Number.png "Number") Stretch, ![Vector](Type-Vector.png "Vector") Color)

Creates a hydraulic constraint with a referenceid, between two bones, at vectors local to each, with constant, damping, relative damping, material, width, stretch only, and color (30 ops)

### hydraulic(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Constant, ![Number](Type-Number.png "Number") Damping, ![Number](Type-Number.png "Number") Rdamping, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Width, ![Number](Type-Number.png "Number") Stretch, ![Vector](Type-Vector.png "Vector") Color)

Creates a hydraulic constraint with a referenceid, between two entities, at vectors local to each, with constant, damping, relative damping, material, width, stretch only, and color (30 ops)

### winch(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Width)

 (30 ops)

### hydraulic(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Width)

Creates a hydraulic constraint with a referenceid, between two entities, at vectors local to each (30 ops)

### hydraulic(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Constant, ![Number](Type-Number.png "Number") Damping, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Width, ![Number](Type-Number.png "Number") Stretch)

Creates a hydraulic constraint with a referenceid, between two entities, at vectors local to each, with constant, damping, and stretch only (30 ops)

### hydraulic(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Constant, ![Number](Type-Number.png "Number") Damping, ![Number](Type-Number.png "Number") Rdamping, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Width, ![Number](Type-Number.png "Number") Stretch)

Creates a hydraulic constraint with a referenceid, between two entities, at vectors local to each, with constant, damping, relative damping material, width, and stretch only (30 ops)

### rope(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Addlength, ![Number](Type-Number.png "Number") Width, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Rigid, ![Vector](Type-Vector.png "Vector") Color)

Creates a rope constraint with a referenceid, between two entities, at vectors local to each with add length, width, material, rigidity, and color (30 ops)

### rope(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone, ![Vector](Type-Vector.png "Vector") V2)

Creates a rope constraint with a referenceid, between an entity and a bone, at vectors local to each (30 ops)

### rope(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Addlength, ![Number](Type-Number.png "Number") Width, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Rigid, ![Vector](Type-Vector.png "Vector") Color)

Creates a rope constraint with a referenceid, between an entity and a bone, at vectors local to each with add length, width, material, rigidity, and color (30 ops)

### rope(![Number](Type-Number.png "Number") Index, ![Bone](Type-Bone.png "Bone") Bone1, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone2, ![Vector](Type-Vector.png "Vector") V2)

Creates a rope constraint with a referenceid, between two bones, at vectors local to each (30 ops)

### rope(![Number](Type-Number.png "Number") Index, ![Bone](Type-Bone.png "Bone") Bone1, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Addlength, ![Number](Type-Number.png "Number") Width, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Rigid, ![Vector](Type-Vector.png "Vector") Color)

Creates a rope constraint with a referenceid, between two bones, at vectors local to each with add length, width, material, rigidity, and color (30 ops)

### rope(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2)

Creates a rope constraint with a referenceid, between two entities, at vectors local to each (30 ops)

### rope(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Addlength, ![Number](Type-Number.png "Number") Width, ![String](Type-String.png "String") Mat)

Creates a rope constraint with a referenceid, between two entities, at vectors local to each with add length, width, and material (30 ops)

### rope(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Addlength, ![Number](Type-Number.png "Number") Width, ![String](Type-String.png "String") Mat, ![Number](Type-Number.png "Number") Rigid)

Creates a rope constraint with a referenceid, between two entities, at vectors local to each with add length, width, material, and rigidity (30 ops)

### ![Entity](Type-Entity.png "Entity"):setLength(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Length)

Sets the length of a winch/hydraulic/rope stored in this entity at a referenceid (5 ops)

### ![Entity](Type-Entity.png "Entity"):setConstant(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Constant)

 (5 ops)

### ![Entity](Type-Entity.png "Entity"):setConstant(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Constant, ![Number](Type-Number.png "Number") Damping)

 (5 ops)

### ![Entity](Type-Entity.png "Entity"):setDamping(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Damping)

 (5 ops)

### slider(![Entity](Type-Entity.png "Entity") Ent, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone, ![Vector](Type-Vector.png "Vector") V2)

 (30 ops)

### slider(![Entity](Type-Entity.png "Entity") Ent, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Width, ![String](Type-String.png "String") Mat, ![Vector](Type-Vector.png "Vector") Color)

 (30 ops)

### slider(![Bone](Type-Bone.png "Bone") Bone1, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone2, ![Vector](Type-Vector.png "Vector") V2)

 (30 ops)

### slider(![Bone](Type-Bone.png "Bone") Bone1, ![Vector](Type-Vector.png "Vector") V1, ![Bone](Type-Bone.png "Bone") Bone2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Width, ![String](Type-String.png "String") Mat, ![Vector](Type-Vector.png "Vector") Color)

 (30 ops)

### slider(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Width, ![String](Type-String.png "String") Mat, ![Vector](Type-Vector.png "Vector") Color)

 (30 ops)

### slider(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2)

 (30 ops)

### slider(![Entity](Type-Entity.png "Entity") Ent1, ![Vector](Type-Vector.png "Vector") V1, ![Entity](Type-Entity.png "Entity") Ent2, ![Vector](Type-Vector.png "Vector") V2, ![Number](Type-Number.png "Number") Width)

 (30 ops)

### ![Entity](Type-Entity.png "Entity"):noCollide(![Entity](Type-Entity.png "Entity") Target)

 (30 ops)

### ![Entity](Type-Entity.png "Entity"):noCollide(![Bone](Type-Bone.png "Bone") Target)

 (30 ops)

### ![Bone](Type-Bone.png "Bone"):noCollide(![Entity](Type-Entity.png "Entity") Target)

 (30 ops)

### ![Bone](Type-Bone.png "Bone"):noCollide(![Bone](Type-Bone.png "Bone") Target)

 (30 ops)

### noCollide(![Entity](Type-Entity.png "Entity") Ent1, ![Entity](Type-Entity.png "Entity") Ent2)

 (30 ops)

### noCollideAll(![Entity](Type-Entity.png "Entity") Ent, ![Number](Type-Number.png "Number") State)

 (30 ops)

### ![Entity](Type-Entity.png "Entity"):weld(![Entity](Type-Entity.png "Entity") Target)

 (30 ops)

### ![Entity](Type-Entity.png "Entity"):weld(![Entity](Type-Entity.png "Entity") Target, ![Number](Type-Number.png "Number") Forcelimit, ![Number](Type-Number.png "Number") Nocollide)

Creates a weld constraint between two entities with force limit (0 for unbreakable) and no collide (30 ops)

### ![Entity](Type-Entity.png "Entity"):weld(![Bone](Type-Bone.png "Bone") Target)

 (30 ops)

### ![Entity](Type-Entity.png "Entity"):weld(![Bone](Type-Bone.png "Bone") Target, ![Number](Type-Number.png "Number") Forcelimit, ![Number](Type-Number.png "Number") Nocollide)

Creates a weld constraint between two entities with force limit (0 for unbreakable) and no collide (30 ops)

### ![Bone](Type-Bone.png "Bone"):weld(![Entity](Type-Entity.png "Entity") Target)

 (30 ops)

### ![Bone](Type-Bone.png "Bone"):weld(![Entity](Type-Entity.png "Entity") Target, ![Number](Type-Number.png "Number") Forcelimit, ![Number](Type-Number.png "Number") Nocollide)

Creates a weld constraint between two entities with force limit (0 for unbreakable) and no collide (30 ops)

### ![Bone](Type-Bone.png "Bone"):weld(![Bone](Type-Bone.png "Bone") Target)

 (30 ops)

### ![Bone](Type-Bone.png "Bone"):weld(![Bone](Type-Bone.png "Bone") Target, ![Number](Type-Number.png "Number") Forcelimit, ![Number](Type-Number.png "Number") Nocollide)

Creates a weld constraint between two bones with force limit (0 for unbreakable) and no collide (30 ops)

### weld(![Entity](Type-Entity.png "Entity") Ent1, ![Entity](Type-Entity.png "Entity") Ent2)

 (30 ops)

### ![Entity](Type-Entity.png "Entity"):constraintBreak()

Breaks all constraints of all types on an entity (5 ops)

### ![Entity](Type-Entity.png "Entity"):constraintBreak(![Entity](Type-Entity.png "Entity") Ent2)

Breaks all constraints between two entities (5 ops)

### ![Entity](Type-Entity.png "Entity"):constraintBreak(![String](Type-String.png "String") Constype)

Breaks all constraints of a type (weld, axis, nocollide, ballsocket) on an entity (5 ops)

### ![Entity](Type-Entity.png "Entity"):constraintBreak(![String](Type-String.png "String") Constype, ![Entity](Type-Entity.png "Entity") Ent2)

Breaks a constraint of a type (weld, axis, nocollide, ballsocket) between two entities (5 ops)
