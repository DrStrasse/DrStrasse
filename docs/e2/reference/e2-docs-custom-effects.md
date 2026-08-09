[Jump to table of contents](#default-extensions)

# Custom/effects

### Effect = effect()

Creates and returns new effect (1 ops)

### Effect = Effect:setOrigin(![Vector](Type-Vector.png "Vector") Pos)

Sets the origin of the effect (1 ops)

### Effect = Effect:setStart(![Vector](Type-Vector.png "Vector") Pos)

Sets the start of the effect (1 ops)

### Effect = Effect:setMagnitude(![Number](Type-Number.png "Number") Mag)

Sets the magnitude of the effect, Magnitude is the amount of particles you will be emitting. (1 ops)

### Effect = Effect:setAngles(![Angle](Type-Angle.png "Angle") Ang)

Sets the angle of the effect (1 ops)

### Effect = Effect:setScale(![Number](Type-Number.png "Number") Scale)

Sets the scale of the effect, scale is the thickness of your effect. (1 ops)

### Effect = Effect:setEntity(![Entity](Type-Entity.png "Entity") Ent)

Sets the entity of the effect (1 ops)

### Effect = Effect:setNormal(![Vector](Type-Vector.png "Vector") Norm)

Sets the normalized direction vector of the effect, aka direction. (1 ops)

### Effect = Effect:setSurfaceProp(![Number](Type-Number.png "Number") Prop)

Sets the surface property index of the effect (1 ops)

### Effect = Effect:setRadius(![Number](Type-Number.png "Number") Radius)

Sets the radius aka size of the effect (1 ops)

### Effect = Effect:setMaterialIndex(![Number](Type-Number.png "Number") Index)

Sets the material index of the effect (1 ops)

### Effect = Effect:setHitBox(![Number](Type-Number.png "Number") Index)

Sets the hit box index of the effect (1 ops)

### Effect = Effect:setFlags(![Number](Type-Number.png "Number") Flags)

Sets the flags of the effect (1 ops)

### Effect = Effect:setEntIndex(![Number](Type-Number.png "Number") Index)

Sets the entity of the effect via its index (1 ops)

### Effect = Effect:setDamageType(![Number](Type-Number.png "Number") Index)

Sets the damage type of the effect. See DMG_ Enums on GMod Wiki (1 ops)

### Effect = Effect:setColor(![Number](Type-Number.png "Number") Index)

Sets the color of the effect. Color is represented by a byte (1 ops)

### Effect = Effect:setAttachment(![Number](Type-Number.png "Number") Index)

Creates new attachment ID for the effect (1 ops)

### Effect:play(![String](Type-String.png "String") Name)

Plays the effect with given name (eg. watersplash) (1 ops)

### ![Number](Type-Number.png "Number") = effectCanPlay()

Returns whether you can play an effect (or 0 if you've hit the burst limit) (1 ops)

### ![Number](Type-Number.png "Number") = effectCanPlay(![String](Type-String.png "String") Name)

Same as effectCanPlay(), but also checks if the specific effect is not allowed (1 ops)
