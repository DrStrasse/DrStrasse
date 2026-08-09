[Jump to table of contents](#default-extensions)

# Angle

### ![Angle](Type-Angle.png "Angle") = ang()

Same as ang(0,0,0) (1 ops)

### ![Angle](Type-Angle.png "Angle") = ang(![Number](Type-Number.png "Number") Rv1)

Makes an angle (2 ops)

### ![Angle](Type-Angle.png "Angle") = ang(![Number](Type-Number.png "Number") Rv1, ![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3)

Makes an angle (2 ops)

### ![Angle](Type-Angle.png "Angle") = ang(![Vector](Type-Vector.png "Vector") Rv1)

Changes a vector variable into an angle variable. XYZ become PYR respectively (2 ops)

### ![Angle](Type-Angle.png "Angle") = angnorm(![Angle](Type-Angle.png "Angle") Rv1)

Gets the normalized angle of an angle (5 ops)

### ![Number](Type-Number.png "Number") = angnorm(![Number](Type-Number.png "Number") Rv1)

Gets the normalized angle of a number (5 ops)

### ![Number](Type-Number.png "Number") = ![Angle](Type-Angle.png "Angle"):pitch()

Gets the pitch of the angle (1 ops)

### ![Number](Type-Number.png "Number") = ![Angle](Type-Angle.png "Angle"):yaw()

Gets the yaw of the angle (1 ops)

### ![Number](Type-Number.png "Number") = ![Angle](Type-Angle.png "Angle"):roll()

Gets the roll of the angle (1 ops)

### ![Angle](Type-Angle.png "Angle") = ![Angle](Type-Angle.png "Angle"):setPitch(![Number](Type-Number.png "Number") Rv2)

Returns a copy of the angle with Pitch replaced (use as Ang = Ang:setPitch(...)) (2 ops)

### ![Angle](Type-Angle.png "Angle") = ![Angle](Type-Angle.png "Angle"):setYaw(![Number](Type-Number.png "Number") Rv2)

Returns a copy of the angle with Yaw replaced (use as Ang = Ang:setYaw(...)) (2 ops)

### ![Angle](Type-Angle.png "Angle") = ![Angle](Type-Angle.png "Angle"):setRoll(![Number](Type-Number.png "Number") Rv2)

Returns a copy of the angle with Roll replaced (use as Ang = Ang:setRoll(...)) (2 ops)

### ![Angle](Type-Angle.png "Angle") = round(![Angle](Type-Angle.png "Angle") Rv1)

Rounds PYR to the nearest integer (5 ops)

### ![Angle](Type-Angle.png "Angle") = round(![Angle](Type-Angle.png "Angle") Rv1, ![Number](Type-Number.png "Number") Decimals)

Rounds PYR to argument 2's decimal precision (5 ops)

### ![Angle](Type-Angle.png "Angle") = ceil(![Angle](Type-Angle.png "Angle") Rv1)

Rounds PYR up to the nearest integer (5 ops)

### ![Angle](Type-Angle.png "Angle") = ceil(![Angle](Type-Angle.png "Angle") Rv1, ![Number](Type-Number.png "Number") Decimals)

Rounds PYR up to argument 2's decimal precision (5 ops)

### ![Angle](Type-Angle.png "Angle") = floor(![Angle](Type-Angle.png "Angle") Rv1)

Rounds PYR down to the nearest integer (5 ops)

### ![Angle](Type-Angle.png "Angle") = floor(![Angle](Type-Angle.png "Angle") Rv1, ![Number](Type-Number.png "Number") Decimals)

Rounds PYR down to argument 2's decimal precision (5 ops)

### ![Angle](Type-Angle.png "Angle") = mod(![Angle](Type-Angle.png "Angle") Rv1, ![Number](Type-Number.png "Number") Rv2)

Returns the remainder after PYR have been divided by argument 2 (5 ops)

### ![Angle](Type-Angle.png "Angle") = mod(![Angle](Type-Angle.png "Angle") Rv1, ![Angle](Type-Angle.png "Angle") Rv2)

Returns the remainder after the components of angle 1 have been divided by the components of angle 2 (5 ops)

### ![Angle](Type-Angle.png "Angle") = clamp(![Angle](Type-Angle.png "Angle") Rv1, ![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3)

Clamps angle 1's PYR between argument 2(min) and argument 3(max) (5 ops)

### ![Angle](Type-Angle.png "Angle") = clamp(![Angle](Type-Angle.png "Angle") Rv1, ![Angle](Type-Angle.png "Angle") Rv2, ![Angle](Type-Angle.png "Angle") Rv3)

Clamps angle 1's PYR between the PYR of angle 2(min) and angle 3(max) (5 ops)

### ![Angle](Type-Angle.png "Angle") = mix(![Angle](Type-Angle.png "Angle") Rv1, ![Angle](Type-Angle.png "Angle") Rv2, ![Number](Type-Number.png "Number") Rv3)

Combines angle 1's PYR with angle 2's PYR by a proportion given by argument 3 (between 0 and 1) (5 ops)

### ![Angle](Type-Angle.png "Angle") = shiftR(![Angle](Type-Angle.png "Angle") Rv1)

Shifts the angle's components right: shiftR( p,y,r ) = ( r,p,y ) (2 ops)

### ![Angle](Type-Angle.png "Angle") = shiftL(![Angle](Type-Angle.png "Angle") Rv1)

Shifts the angle's components left: shiftL( p,y,r ) = ( y,r,p ) (2 ops)

### ![Number](Type-Number.png "Number") = inrange(![Angle](Type-Angle.png "Angle") Rv1, ![Angle](Type-Angle.png "Angle") Rv2, ![Angle](Type-Angle.png "Angle") Rv3)

Returns 1 if each component of A is between (or is equal to) the components of Amin and Amax (5 ops)

### ![Angle](Type-Angle.png "Angle") = ![Angle](Type-Angle.png "Angle"):rotateAroundAxis(![Vector](Type-Vector.png "Vector") Axis, ![Number](Type-Number.png "Number") Degrees)

Returns the angle A rotated around vector V by N degrees (5 ops)

### ![Angle](Type-Angle.png "Angle") = toRad(![Angle](Type-Angle.png "Angle") Rv1)

Converts the angle's magnitude from radians to radians (5 ops)

### ![Angle](Type-Angle.png "Angle") = toDeg(![Angle](Type-Angle.png "Angle") Rv1)

Converts the angle's magnitude from radians to degrees (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Angle](Type-Angle.png "Angle"):forward()

Gets the forward vector of the angle (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Angle](Type-Angle.png "Angle"):right()

Gets the right vector of the angle (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Angle](Type-Angle.png "Angle"):up()

Gets the up vector of the angle (5 ops)

### ![String](Type-String.png "String") = toString(![Angle](Type-Angle.png "Angle") A)

Gets the angle nicely formatted as a string "[P,Y,R]" (5 ops)

### ![String](Type-String.png "String") = ![Angle](Type-Angle.png "Angle"):toString()

Gets the angle nicely formatted as a string "[P,Y,R]" (5 ops)
