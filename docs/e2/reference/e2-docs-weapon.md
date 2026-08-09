[Jump to table of contents](#default-extensions)

# Weapon

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):weapon()

Returns the weapon that player E is currently holding (2 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):weapon(![String](Type-String.png "String") Weaponclassname)

Returns the weapon with specified class of player E (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):hasWeapon(![String](Type-String.png "String") Classname)

Returns 1 if player E has a weapon with class S, 0 otherwise (2 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):weapons()

Returns the weapons that player E has (2 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):primaryAmmoType()

Returns the name of the primary weapon's ammo (2 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):secondaryAmmoType()

Returns the name of the secondary weapon's ammo (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):ammoCount(![String](Type-String.png "String") Ammo_type)

Returns the amount of stored ammo of type S on player E, excluding current clip (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):clip1()

Returns the amount of ammo in the primary clip of weapon E, -1 if there is no primary clip (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):clip1Size()

Returns the maximum size of the primary clip (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):setClip1(![Number](Type-Number.png "Number") Amount)

Sets the amount of ammo in the primary clip of weapon E. Requires wire_expression2_weapon_ammo_set_enable to be set to 1. (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):clip2()

Returns the amount of ammo in the secondary clip of weapon E, -1 if there is no secondary clip 1) (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):clip2Size()

Returns the maximum size of the secondary clip (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):setClip2(![Number](Type-Number.png "Number") Amount)

Sets the amount of ammo in the secondary clip of weapon E. Requires wire_expression2_weapon_ammo_set_enable to be set to 1. (2 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):tool()

returns the name of the tool the player E is currently holding (2 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):giveWeapon(![String](Type-String.png "String") Classname)

Gives player E the weapon with class S. Requires wire_expression2_weapon_give_enable to be set to 1. (2 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):giveWeapon(![String](Type-String.png "String") Classname, ![Number](Type-Number.png "Number") Noammo)

Gives player E the weapon with class S. If N is not 0, the weapon will be given with full ammo. Requires wire_expression2_weapon_give_enable to be set to 1. (2 ops)

### ![Entity](Type-Entity.png "Entity"):selectWeapon(![String](Type-String.png "String") Classname)

Sets the active weapon with class S on player E (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):giveAmmo(![Number](Type-Number.png "Number") Amount, ![String](Type-String.png "String") Type)

Gives the player E N amount of ammo of type S. Requires wire_expression2_weapon_ammo_give_enable to be set to 1. (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):giveAmmo(![Number](Type-Number.png "Number") Amount, ![String](Type-String.png "String") Type, ![Number](Type-Number.png "Number") Hidepopup)

Gives the player E N amount of ammo of type S. If N is not 0, the pop-up will not appear. Requires wire_expression2_weapon_ammo_give_enable to be set to 1. (2 ops)

### ![Entity](Type-Entity.png "Entity"):setAmmo(![Number](Type-Number.png "Number") Ammocount, ![String](Type-String.png "String") Type)

Sets the amount of ammo of type S on player E to N. Requires wire_expression2_weapon_ammo_set_enable to be set to 1. (2 ops)

### ![Entity](Type-Entity.png "Entity"):removeAmmo(![Number](Type-Number.png "Number") Ammocount, ![String](Type-String.png "String") Type)

Removes N amount ammo of type S from player E. Requires wire_expression2_weapon_ammo_set_enable to be set to 1. (2 ops)

### ![Entity](Type-Entity.png "Entity"):removeAllAmmo()

Removes all ammo from the player E. Requires wire_expression2_weapon_ammo_set_enable to be set to 1. (2 ops)

### ![Entity](Type-Entity.png "Entity"):stripWeapon(![String](Type-String.png "String") Classname)

Removes the weapon with class S from player E. Requires wire_expression2_weapon_strip_enable to be set to 1. (2 ops)

### ![Entity](Type-Entity.png "Entity"):stripWeapons()

Removes all weapons from player E. Requires wire_expression2_weapon_strip_enable to be set to 1. (2 ops)
