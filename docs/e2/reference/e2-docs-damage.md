[Jump to table of contents](#default-extensions)

# Damage

### ![Number](Type-Number.png "Number") = Damage:isType(![Number](Type-Number.png "Number") Type)

Returns whether the damage contains the type flag provided. For example isType(_DMG_BLAST) would return 1 if the damage contains blast damage. (1 ops)

### ![Number](Type-Number.png "Number") = Damage:getAmount()

Returns the amount of damage dealt (1 ops)

### ![Vector](Type-Vector.png "Vector") = Damage:getPosition()

Returns the position where the damage was dealt (1 ops)

### ![Vector](Type-Vector.png "Vector") = Damage:getForce()

Returns the force of the damage dealt (1 ops)

### ![Entity](Type-Entity.png "Entity") = Damage:getInflictor()

Returns the inflictor (weapon) which caused the damage to be dealt (1 ops)

### ![Entity](Type-Entity.png "Entity") = Damage:getAttacker()

Returns the attacker which used the inflictor to deal the damage (1 ops)

### ![Number](Type-Number.png "Number") = Damage:getAmmoType()

Returns the ammo type id of the damage dealt (1 ops)

### ![Entity](Type-Entity.png "Entity"):takeDamage(![Number](Type-Number.png "Number") Amount)

Applies an amount of damage to the player. Requires wire_expression2_damage_enabled to be set to 1. (20 ops)

### ![Entity](Type-Entity.png "Entity"):takeDamage(![Number](Type-Number.png "Number") Amount, ![Entity](Type-Entity.png "Entity") Attacker)

Applies an amount of damage to the player with given attacker. Requires wire_expression2_damage_enabled to be set to 1. (20 ops)

### ![Entity](Type-Entity.png "Entity"):takeDamage(![Number](Type-Number.png "Number") Amount, ![Entity](Type-Entity.png "Entity") Attacker, ![Entity](Type-Entity.png "Entity") Inflictor)

Applies an amount of damage to the player with given attacker and inflictor. Requires wire_expression2_damage_enabled to be set to 1. (20 ops)

### blastDamage(![Vector](Type-Vector.png "Vector") Origin, ![Number](Type-Number.png "Number") Radius, ![Number](Type-Number.png "Number") Damage)

Creates blast damage at the position provided with specified radius and damage amount. Requires wire_expression2_damage_enabled to be set to 1. (10 ops)
