[Jump to table of contents](#table-of-contents)

# Custom/ftrace

### Ftrace = noFTrace()

Returns invalid flash trace object (1 ops)

### Ftrace = ![Entity](Type-Entity.png "Entity"):setFTrace(![Vector](Type-Vector.png "Vector") Vp, ![Vector](Type-Vector.png "Vector") Vd, ![Number](Type-Number.png "Number") Nl)

Returns flash trace local to the entity by origin position, direction vector, length distance (20 ops)

### Ftrace = newFTrace(![Vector](Type-Vector.png "Vector") Vp, ![Vector](Type-Vector.png "Vector") Vd, ![Number](Type-Number.png "Number") Nl)

Returns flash trace relative to the world by origin position, direction vector, length distance (20 ops)

### Ftrace = ![Entity](Type-Entity.png "Entity"):setFTrace(![Vector](Type-Vector.png "Vector") Vp, ![Vector](Type-Vector.png "Vector") Vd)

Returns flash trace local to the entity by origin position, direction vector, length distance from direction vector (20 ops)

### Ftrace = newFTrace(![Vector](Type-Vector.png "Vector") Vp, ![Vector](Type-Vector.png "Vector") Vd)

Returns flash trace relative to the world by origin position, direction vector, length distance from direction vector (20 ops)

### Ftrace = ![Entity](Type-Entity.png "Entity"):setFTrace(![Vector](Type-Vector.png "Vector") Vp, ![Number](Type-Number.png "Number") Nl)

Returns flash trace relative to the entity by origin position, direction vector from up, length distance (20 ops)

### Ftrace = newFTrace(![Vector](Type-Vector.png "Vector") Vp, ![Number](Type-Number.png "Number") Nl)

Returns flash trace relative to the world by origin position, direction vector from up, length distance (20 ops)

### Ftrace = ![Entity](Type-Entity.png "Entity"):setFTrace(![Vector](Type-Vector.png "Vector") Vp)

Returns flash trace local to the entity by origin position, zero direction vector, zero length distance (20 ops)

### Ftrace = newFTrace(![Vector](Type-Vector.png "Vector") Vp)

Returns flash trace relative to the world by origin position, zero direction vector, zero length distance (20 ops)

### Ftrace = ![Entity](Type-Entity.png "Entity"):setFTrace(![Number](Type-Number.png "Number") Nl)

Returns flash trace relative to the entity by length distance, direction vector, zero length distance (20 ops)

### Ftrace = newFTrace(![Number](Type-Number.png "Number") Nl)

Returns flash trace relative to the world by length distance, direction vector, zero length distance (20 ops)

### Ftrace = ![Entity](Type-Entity.png "Entity"):setFTrace()

Returns flash trace local to the entity by zero origin position, zero direction vector, zero length distance (20 ops)

### Ftrace = newFTrace()

Returns flash trace relative to the world by zero origin position, zero direction vector, zero length distance (20 ops)

### Ftrace = Ftrace:getCopy(![Entity](Type-Entity.png "Entity") Ee, ![Vector](Type-Vector.png "Vector") Vp, ![Vector](Type-Vector.png "Vector") Vd, ![Number](Type-Number.png "Number") Nl)

Returns flash trace copy instance of the current object using other entity, origin, direction and length (20 ops)

### Ftrace = Ftrace:getCopy(![Vector](Type-Vector.png "Vector") Vp, ![Vector](Type-Vector.png "Vector") Vd, ![Number](Type-Number.png "Number") Nl)

Returns flash trace copy instance of the current object using other origin, direction and length (20 ops)

### Ftrace = Ftrace:getCopy(![Entity](Type-Entity.png "Entity") Ee, ![Vector](Type-Vector.png "Vector") Vp, ![Vector](Type-Vector.png "Vector") Vd)

Returns flash trace copy instance of the current object using other entity, origin and direction (20 ops)

### Ftrace = Ftrace:getCopy(![Vector](Type-Vector.png "Vector") Vp, ![Vector](Type-Vector.png "Vector") Vd)

Returns flash trace copy instance of the current object using other origin and direction (20 ops)

### Ftrace = Ftrace:getCopy(![Entity](Type-Entity.png "Entity") Ee, ![Vector](Type-Vector.png "Vector") Vp, ![Number](Type-Number.png "Number") Nl)

Returns flash trace copy instance of the current object using other entity, origin and length (20 ops)

### Ftrace = Ftrace:getCopy(![Vector](Type-Vector.png "Vector") Vp, ![Number](Type-Number.png "Number") Nl)

Returns flash trace copy instance of the current object using other origin and length (20 ops)

### Ftrace = Ftrace:getCopy(![Entity](Type-Entity.png "Entity") Ee, ![Vector](Type-Vector.png "Vector") Vp)

Returns flash trace copy instance of the current object using other entity and origin (20 ops)

### Ftrace = Ftrace:getCopy(![Vector](Type-Vector.png "Vector") Vp)

Returns flash trace copy instance of the current object using other origin (20 ops)

### Ftrace = Ftrace:getCopy(![Entity](Type-Entity.png "Entity") Ee, ![Number](Type-Number.png "Number") Nl)

Returns flash trace copy instance of the current object using other entity and length (20 ops)

### Ftrace = Ftrace:getCopy(![Number](Type-Number.png "Number") Nl)

Returns flash trace copy instance of the current object using other length (20 ops)

### Ftrace = Ftrace:getCopy(![Entity](Type-Entity.png "Entity") Ee)

Returns flash trace copy instance of the current object using other entity (20 ops)

### Ftrace = Ftrace:getCopy()

Returns flash trace copy instance of the current object (20 ops)

### Ftrace = Ftrace:addEntHitSkip(![Entity](Type-Entity.png "Entity") Ve)

Adds the entity to the flash trace internal ignore hit list (3 ops)

### Ftrace = Ftrace:remEntHitSkip(![Entity](Type-Entity.png "Entity") Ve)

Removes the entity from the flash trace internal ignore hit list (3 ops)

### Ftrace = Ftrace:remEntHitSkip()

Removes all the entities from the flash trace internal ignore hit list (3 ops)

### Ftrace = Ftrace:addEntHitOnly(![Entity](Type-Entity.png "Entity") Ve)

Adds the entity to the flash trace internal only hit list (3 ops)

### Ftrace = Ftrace:remEntHitOnly(![Entity](Type-Entity.png "Entity") Ve)

Removes the entity from the flash trace internal only hit list (3 ops)

### Ftrace = Ftrace:remEntHitOnly()

Removes all the entities from the flash trace internal only hit list (3 ops)

### Ftrace = Ftrace:remEntHit()

Removes all the entities from the flash trace internal hit list (3 ops)

### Ftrace = Ftrace:remHit()

Removes all the options from the flash trace internal hit preferences (3 ops)

### Ftrace = Ftrace:remHit(![String](Type-String.png "String") Sm)

Removes the option from the flash trace internal hit preferences (3 ops)

### Ftrace = Ftrace:addHitSkip(![String](Type-String.png "String") Sm, ![Number](Type-Number.png "Number") Vn)

Adds the option to the flash trace internal ignore hit list (3 ops)

### Ftrace = Ftrace:remHitSkip(![String](Type-String.png "String") Sm, ![Number](Type-Number.png "Number") Vn)

Removes the option from the flash trace internal ignore hit list (3 ops)

### Ftrace = Ftrace:addHitOnly(![String](Type-String.png "String") Sm, ![Number](Type-Number.png "Number") Vn)

Adds the option to the flash trace internal hit only list (3 ops)

### Ftrace = Ftrace:remHitOnly(![String](Type-String.png "String") Sm, ![Number](Type-Number.png "Number") Vn)

Removes the option from the flash trace internal only hit list (3 ops)

### Ftrace = Ftrace:addHitSkip(![String](Type-String.png "String") Sm, ![String](Type-String.png "String") Vs)

Adds the option to the flash trace internal ignore hit list (3 ops)

### Ftrace = Ftrace:remHitSkip(![String](Type-String.png "String") Sm, ![String](Type-String.png "String") Vs)

Removes the option from the flash trace internal ignore hit list (3 ops)

### Ftrace = Ftrace:addHitOnly(![String](Type-String.png "String") Sm, ![String](Type-String.png "String") Vs)

Adds the option to the flash trace internal hit only list (3 ops)

### Ftrace = Ftrace:remHitOnly(![String](Type-String.png "String") Sm, ![String](Type-String.png "String") Vs)

Removes the option from the flash trace internal only hit list (3 ops)

### Ftrace = Ftrace:rayMove()

Moves the flash trace ray with its own direction and magnitude (3 ops)

### Ftrace = Ftrace:rayMove(![Number](Type-Number.png "Number") Nl)

Moves the flash trace ray with its own direction and magnitude length (3 ops)

### Ftrace = Ftrace:rayMove(![Vector](Type-Vector.png "Vector") Vv)

Moves the flash trace ray with displacement vector (3 ops)

### Ftrace = Ftrace:rayMove(![Number](Type-Number.png "Number") Nx, ![Number](Type-Number.png "Number") Ny, ![Number](Type-Number.png "Number") Nz)

Moves the flash trace ray with displacement as three numbers (3 ops)

### Ftrace = Ftrace:rayMove(![Vector](Type-Vector.png "Vector") Vv, ![Number](Type-Number.png "Number") Nl)

Moves the flash trace ray with direction vector, magnitude length (3 ops)

### Ftrace = Ftrace:rayAmend(![Vector](Type-Vector.png "Vector") Vv)

Amends the flash trace ray direction using a vector (3 ops)

### Ftrace = Ftrace:rayAmend(![Number](Type-Number.png "Number") Nx, ![Number](Type-Number.png "Number") Ny, ![Number](Type-Number.png "Number") Nz)

Amends the flash trace ray direction using three numbers (3 ops)

### Ftrace = Ftrace:rayAmend(![Vector](Type-Vector.png "Vector") Vv, ![Number](Type-Number.png "Number") Nl)

Amends the flash trace ray direction using vector and magnitude (3 ops)

### Ftrace = Ftrace:rayMul(![Number](Type-Number.png "Number") Nn)

Expands the flash trace ray with a number (3 ops)

### Ftrace = Ftrace:rayMul(![Vector](Type-Vector.png "Vector") Vv)

Expands the flash trace ray each component individually using a vector (3 ops)

### Ftrace = Ftrace:rayMul(![Number](Type-Number.png "Number") Nx, ![Number](Type-Number.png "Number") Ny, ![Number](Type-Number.png "Number") Nz)

Expands the flash trace ray each component individually using three numbers (3 ops)

### Ftrace = Ftrace:rayDiv(![Number](Type-Number.png "Number") Nn)

Contracts the flash trace ray with a number (3 ops)

### Ftrace = Ftrace:rayDiv(![Vector](Type-Vector.png "Vector") Vv)

Contracts the flash trace ray each component individually using a vector (3 ops)

### Ftrace = Ftrace:rayDiv(![Number](Type-Number.png "Number") Nx, ![Number](Type-Number.png "Number") Ny, ![Number](Type-Number.png "Number") Nz)

Contracts the flash trace ray each component individually using three numbers (3 ops)

### Ftrace = Ftrace:rayAim(![Vector](Type-Vector.png "Vector") Vv)

Aims the flash trace ray at a given position using a vector (3 ops)

### Ftrace = Ftrace:rayAim(![Number](Type-Number.png "Number") Nx, ![Number](Type-Number.png "Number") Ny, ![Number](Type-Number.png "Number") Nz)

Aims the flash trace ray at a given position using three numbers (3 ops)

### ![Entity](Type-Entity.png "Entity") = Ftrace:getChip()

Returns the flash trace auto-assigned expression chip entity (3 ops)

### ![Entity](Type-Entity.png "Entity") = Ftrace:getBase()

Returns the flash trace base attachment entity if available (3 ops)

### Ftrace = Ftrace:setBase(![Entity](Type-Entity.png "Entity") Ee)

Updates the flash trace base attachment entity (3 ops)

### Ftrace = Ftrace:remBase()

Removes the base attachment entity of the flash trace (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:isIgnoreWorld()

Returns the flash trace trace `IgnoreWorld` flag (3 ops)

### Ftrace = Ftrace:setIsIgnoreWorld(![Number](Type-Number.png "Number") Nn)

Updates the flash trace trace `IgnoreWorld` flag (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getPos()

Returns flash trace origin position (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getPosLocal()

Returns flash trace world origin position converted to base attachment entity local axis (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getPosWorld()

Returns flash trace local origin position converted to base attachment entity world axis (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getPosLocal(![Entity](Type-Entity.png "Entity") Ve)

Returns flash trace world origin position converted to entity local axis (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getPosWorld(![Entity](Type-Entity.png "Entity") Ve)

Returns flash trace local origin position converted to entity world axis (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getPosLocal(![Vector](Type-Vector.png "Vector") Vp, ![Angle](Type-Angle.png "Angle") Va)

Returns flash trace world origin position converted to position/angle local axis (7 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getPosWorld(![Vector](Type-Vector.png "Vector") Vp, ![Angle](Type-Angle.png "Angle") Va)

Returns flash trace local origin position converted to position/angle world axis (7 ops)

### Ftrace = Ftrace:setPos(![Vector](Type-Vector.png "Vector") Vo)

Updates the flash trace origin position (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getDir()

Returns flash trace direction vector (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getDirLocal()

Returns flash trace world direction vector converted to base attachment entity local axis (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getDirWorld()

Returns flash trace local direction vector converted to base attachment entity world axis (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getDirLocal(![Entity](Type-Entity.png "Entity") Ve)

Returns flash trace world direction vector converted to entity local axis (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getDirWorld(![Entity](Type-Entity.png "Entity") Ve)

Returns flash trace local direction vector converted to entity world axis (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getDirLocal(![Angle](Type-Angle.png "Angle") Va)

Returns flash trace world direction vector converted to angle local axis (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getDirWorld(![Angle](Type-Angle.png "Angle") Va)

Returns flash trace local direction vector converted to angle world axis (3 ops)

### Ftrace = Ftrace:setDir(![Vector](Type-Vector.png "Vector") Vd)

Updates the flash trace direction vector (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getLen()

Returns flash trace length distance (3 ops)

### Ftrace = Ftrace:setLen(![Number](Type-Number.png "Number") Nl)

Updates flash trace length distance (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getMask()

Returns flash trace trace hit mask enums MASK (3 ops)

### Ftrace = Ftrace:setMask(![Number](Type-Number.png "Number") Nn)

Updates flash trace trace hit mask enums MASK (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getCollideGroup()

Returns flash trace trace collision group enums COLLISION_GROUP (3 ops)

### Ftrace = Ftrace:setCollideGroup(![Number](Type-Number.png "Number") Nn)

Updates flash trace trace collision group enums COLLISION_GROUP (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getStart()

Returns flash trace trace start position sent to trace-line (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getStop()

Returns flash trace trace stop position sent to trace-line (3 ops)

### Ftrace = Ftrace:smpLocal()

Samples the flash trace and updates the trace-result by base attachment entity local axis (12 ops)

### Ftrace = Ftrace:smpLocal(![Entity](Type-Entity.png "Entity") Ve)

Samples the flash trace and updates the trace-result by entity position and forward vectors (12 ops)

### Ftrace = Ftrace:smpLocal(![Angle](Type-Angle.png "Angle") Va)

Samples the flash trace and updates the trace-result by base position, angle (12 ops)

### Ftrace = Ftrace:smpLocal(![Vector](Type-Vector.png "Vector") Vp)

Samples the flash trace and updates the trace-result by position, base angle (12 ops)

### Ftrace = Ftrace:smpLocal(![Vector](Type-Vector.png "Vector") Vp, ![Angle](Type-Angle.png "Angle") Va)

Samples the flash trace and updates the trace-result by position, angle (12 ops)

### Ftrace = Ftrace:smpLocal(![Entity](Type-Entity.png "Entity") Ve, ![Vector](Type-Vector.png "Vector") Vp)

Samples the flash trace and updates the trace-result by position, entity angle (12 ops)

### Ftrace = Ftrace:smpLocal(![Entity](Type-Entity.png "Entity") Ve, ![Angle](Type-Angle.png "Angle") Va)

Samples the flash trace and updates the trace-result by entity position, angle (12 ops)

### Ftrace = Ftrace:smpWorld()

Samples the flash trace and updates the trace-result by the world axis (12 ops)

### Ftrace = Ftrace:smpWorld(![Entity](Type-Entity.png "Entity") Ve)

Samples the flash trace and updates the trace-result by entity position and forward vectors (12 ops)

### Ftrace = Ftrace:smpWorld(![Angle](Type-Angle.png "Angle") Va)

Samples the flash trace and updates the trace-result by entity position and angle forward (12 ops)

### Ftrace = Ftrace:smpWorld(![Vector](Type-Vector.png "Vector") Vp)

Samples the flash trace and updates the trace-result by position vector and entity forward (12 ops)

### Ftrace = Ftrace:smpWorld(![Vector](Type-Vector.png "Vector") Vp, ![Angle](Type-Angle.png "Angle") Va)

Samples the flash trace and updates the trace-result by position, angle (12 ops)

### Ftrace = Ftrace:smpWorld(![Entity](Type-Entity.png "Entity") Ve, ![Vector](Type-Vector.png "Vector") Vp)

Samples the flash trace and updates the trace-result by position, entity angle (12 ops)

### Ftrace = Ftrace:smpWorld(![Entity](Type-Entity.png "Entity") Ve, ![Angle](Type-Angle.png "Angle") Va)

Samples the flash trace and updates the trace-result by entity position, angle (12 ops)

### ![Number](Type-Number.png "Number") = Ftrace:isHitNoDraw()

Returns the flash trace trace-result `HitNoDraw` flag (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:isHitNonWorld()

Returns the flash trace trace-result `HitNonWorld` flag (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:isHit()

Returns the flash trace trace-result `Hit` flag (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:isHitSky()

Returns the flash trace trace-result `HitSky` flag (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:isHitWorld()

Returns the flash trace trace-result `HitWorld` flag (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getHitBox()

Returns the flash trace trace-result `HitBox` number (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getMatType()

Returns the flash trace trace-result `MatType` material type number (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getHitGroup()

Returns the flash trace trace-result `HitGroup` group ID number (3 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getHitPos()

Returns the flash trace trace-result `HitPos` location vector (8 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getHitNormal()

Returns flash trace trace-result surface `HitNormal` vector (8 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getNormal()

Returns the flash trace trace-result `Normal` aim vector (8 ops)

### ![String](Type-String.png "String") = Ftrace:getHitTexture()

Returns the flash trace trace-result `HitTexture` string (8 ops)

### ![Vector](Type-Vector.png "Vector") = Ftrace:getStartPos()

Returns the flash trace trace-result `StartPos` vector (8 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getSurfPropsID()

Returns the flash trace trace-result `SurfaceProps` ID type number (3 ops)

### ![String](Type-String.png "String") = Ftrace:getSurfPropsName()

Returns the flash trace trace-result `SurfaceProps` ID type name string (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getBone()

Returns the flash trace trace-result `PhysicsBone` ID number (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getFraction()

Returns the flash trace trace-result `Fraction` in the interval [0-1] number (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getFractionLen()

Returns the flash trace trace-result `Fraction` multiplied by its length distance number (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:isStartSolid()

Returns the flash trace trace-result `StartSolid` flag (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:isAllSolid()

Returns the flash trace trace-result `AllSolid` flag (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getFractionLS()

Returns the flash trace trace-result `FractionLeftSolid` in the interval [0-1] number (3 ops)

### ![Number](Type-Number.png "Number") = Ftrace:getFractionLenLS()

Returns the flash trace trace-result `FractionLeftSolid` multiplied by its length distance number (3 ops)

### ![Entity](Type-Entity.png "Entity") = Ftrace:getEntity()

Returns the flash trace trace-result `Entity` entity (3 ops)

### Ftrace = Ftrace:dumpItem(![Number](Type-Number.png "Number") Nn)

Dumps the flash trace to the chat area by number identifier (15 ops)

### Ftrace = Ftrace:dumpItem(![String](Type-String.png "String") Sn)

Dumps the flash trace to the chat area by string identifier (15 ops)

### Ftrace = Ftrace:dumpItem(![String](Type-String.png "String") Nt, ![Number](Type-Number.png "Number") Nn)

Dumps the flash trace by number identifier in the specified area by first argument (15 ops)

### Ftrace = Ftrace:dumpItem(![String](Type-String.png "String") Nt, ![String](Type-String.png "String") Sn)

Dumps the flash trace by string identifier in the specified area by first argument (15 ops)
