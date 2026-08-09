[Jump to table of contents](#default-extensions)

# Compat

### ![String](Type-String.png "String") = ![Number](Type-Number.png "Number"):teamName()

Returns the name of the team associated with the team number (10 ops)

### ![Number](Type-Number.png "Number") = ![Number](Type-Number.png "Number"):teamScore()

Returns the score of the team associated with the team number (10 ops)

### ![Number](Type-Number.png "Number") = ![Number](Type-Number.png "Number"):teamPlayers()

Returns the number of players of the team associated with the team number (10 ops)

### ![Number](Type-Number.png "Number") = ![Number](Type-Number.png "Number"):teamDeaths()

Returns the number of deaths of the team associated with the team number (10 ops)

### ![Number](Type-Number.png "Number") = ![Number](Type-Number.png "Number"):teamFrags()

Returns the number of kills of the team associated with the team number (10 ops)

### setColor(![Number](Type-Number.png "Number") R, ![Number](Type-Number.png "Number") G, ![Number](Type-Number.png "Number") B)

Sets the color of the E2 chip (10 ops)

### applyForce(![Vector](Type-Vector.png "Vector") Force)

Applies force to the E2 chip according to the given vector's direction and magnitude (30 ops)

### applyOffsetForce(![Vector](Type-Vector.png "Vector") Force, ![Vector](Type-Vector.png "Vector") Position)

Applies force to the E2 chip according to the first vector from the location of the second (30 ops)

### applyAngForce(![Angle](Type-Angle.png "Angle") Angforce)

Applies torque to the E2 chip according to the given angle (30 ops)

### applyTorque(![Vector](Type-Vector.png "Vector") Torque)

Applies torque to the E2 chip according to the given vector, representing the torque axis, magnitude and direction (30 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):height()

Gets the height of a player or npc (10 ops)
