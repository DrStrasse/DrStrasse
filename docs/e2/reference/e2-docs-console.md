[Jump to table of contents](#default-extensions)

# Console

### ![Number](Type-Number.png "Number") = concmd(![String](Type-String.png "String") Command)

Takes a string and executes it in console. Returns 1 if it succeeded and 0 if it failed.The client must enable this in the console with "wire_expression2_concmd 1". "wire_expression2_concmd_whitelist" allows you to choose which commands can be used.[http://www.wiremod.com/forum/151800-post12.html] (5 ops)

### ![String](Type-String.png "String") = convar(![String](Type-String.png "String") Cvar)

Give a console command such as "name" and it returns the set value (5 ops)

### ![Number](Type-Number.png "Number") = convarnum(![String](Type-String.png "String") Cvar)

Give a console command such as "sbox_godmode" and it returns the set value (5 ops)

### ![Number](Type-Number.png "Number") = maxOfType(![String](Type-String.png "String") Typename)

Returns the maximum allowed of a certain type of entity, i.e. maxOfType("wire_thrusters"). Returns 0 if you enter an invalid parameter (5 ops)

### ![Number](Type-Number.png "Number") = playerDamage()

Returns 1 if player vs player damage is enabled on the server (5 ops)
