[Jump to table of contents](#default-extensions)

# Vector

### ![Vector](Type-Vector.png "Vector") = vec()

Same as vec(0,0,0) (1 ops)

### ![Vector](Type-Vector.png "Vector") = vec(![Number](Type-Number.png "Number") X)

Makes a 3D vector (2 ops)

### ![Vector](Type-Vector.png "Vector") = vec(![Number](Type-Number.png "Number") X, ![Number](Type-Number.png "Number") Y, ![Number](Type-Number.png "Number") Z)

Makes a 3D vector (2 ops)

### ![Vector](Type-Vector.png "Vector") = vec(![Vector2](Type-Vector2.png "Vector2") V2)

Converts a 2D vector into a 3D vector (the z component is set to 0) (2 ops)

### ![Vector](Type-Vector.png "Vector") = vec(![Vector2](Type-Vector2.png "Vector2") V2, ![Number](Type-Number.png "Number") Z)

Converts a 2D vector into a 3D vector (the z component is set to the second argument) (2 ops)

### ![Vector](Type-Vector.png "Vector") = vec(![Vector4](Type-Vector4.png "Vector4") V4)

Converts a 4D vector into a 3D vector (the w component is dropped) (2 ops)

### ![Vector](Type-Vector.png "Vector") = vec(![Angle](Type-Angle.png "Angle") Ang)

Changes an angle variable into a vector variable. PYR become XYZ respectively (2 ops)

### ![Vector](Type-Vector.png "Vector") = randvec()

Returns a uniformly distributed, random, normalized direction vector (10 ops)

### ![Vector](Type-Vector.png "Vector") = randvec(![Number](Type-Number.png "Number") Min, ![Number](Type-Number.png "Number") Max)

Returns a random vector with its components between N1 and N2 (5 ops)

### ![Vector](Type-Vector.png "Vector") = randvec(![Vector](Type-Vector.png "Vector") Min, ![Vector](Type-Vector.png "Vector") Max)

Returns a random vector between V1 and V2 (5 ops)

### ![Number](Type-Number.png "Number") = ![Vector](Type-Vector.png "Vector"):length()

Gets the length of the vector (2 ops)

### ![Number](Type-Number.png "Number") = ![Vector](Type-Vector.png "Vector"):length2()

Gets the squared length of the vector (2 ops)

### ![Number](Type-Number.png "Number") = ![Vector](Type-Vector.png "Vector"):distance(![Vector](Type-Vector.png "Vector") Other)

Gets the distance between vectors (2 ops)

### ![Number](Type-Number.png "Number") = ![Vector](Type-Vector.png "Vector"):distance2(![Vector](Type-Vector.png "Vector") Other)

Gets the squared distance between vectors (2 ops)

### ![Vector](Type-Vector.png "Vector") = ![Vector](Type-Vector.png "Vector"):normalized()

Gets the normalized vector (2 ops)

### ![Number](Type-Number.png "Number") = ![Vector](Type-Vector.png "Vector"):dot(![Vector](Type-Vector.png "Vector") Other)

Gets the vector dot (scalar) product (2 ops)

### ![Vector](Type-Vector.png "Vector") = ![Vector](Type-Vector.png "Vector"):cross(![Vector](Type-Vector.png "Vector") Other)

Gets the vector cross product (2 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Vector](Type-Vector.png "Vector"):outerProduct(![Vector](Type-Vector.png "Vector") Other)

Gets the outer product (tensor product) and returns a matrix (tensor) (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![Vector](Type-Vector.png "Vector"):rotateAroundAxis(![Vector](Type-Vector.png "Vector") Axis, ![Number](Type-Number.png "Number") Degrees)

Returns the vector V1 rotated around vector V2 by N degrees (15 ops)

### ![Vector](Type-Vector.png "Vector") = ![Vector](Type-Vector.png "Vector"):rotate(![Angle](Type-Angle.png "Angle") Ang)

Gets the rotated vector (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Vector](Type-Vector.png "Vector"):rotate(![Number](Type-Number.png "Number") Pitch, ![Number](Type-Number.png "Number") Yaw, ![Number](Type-Number.png "Number") Roll)

Gets the rotated vector (5 ops)

### ![Vector2](Type-Vector2.png "Vector2") = ![Vector](Type-Vector.png "Vector"):dehomogenized()

Converts a 2D homogeneous vector (x,y,w) into a 2D cartesian vector (5 ops)

### ![Vector](Type-Vector.png "Vector") = positive(![Vector](Type-Vector.png "Vector") Rv1)

Returns a vector containing the positive value of each vector component, equivalent to abs(N) (5 ops)

### ![Vector](Type-Vector.png "Vector") = toRad(![Vector](Type-Vector.png "Vector") Rv1)

Converts the vector's magnitude from radians to radians (3 ops)

### ![Vector](Type-Vector.png "Vector") = toDeg(![Vector](Type-Vector.png "Vector") Rv1)

Converts the vector's magnitude from radians to degrees (3 ops)

### ![Vector](Type-Vector.png "Vector") = clamp(![Vector](Type-Vector.png "Vector") Input, ![Number](Type-Number.png "Number") Min, ![Number](Type-Number.png "Number") Max)

Returns a vector in the same direction as vector 1, with length clamped between argument 2(min) and argument 3(max) (5 ops)

### ![Number](Type-Number.png "Number") = ![Vector](Type-Vector.png "Vector"):x()

Gets the x component of the vector (1 ops)

### ![Number](Type-Number.png "Number") = ![Vector](Type-Vector.png "Vector"):y()

Gets the y component of the vector (1 ops)

### ![Number](Type-Number.png "Number") = ![Vector](Type-Vector.png "Vector"):z()

Gets the z component of the vector (1 ops)

### ![Vector](Type-Vector.png "Vector") = ![Vector](Type-Vector.png "Vector"):setX(![Number](Type-Number.png "Number") X)

Returns a copy of the vector with X replaced (use as Vec = Vec:setX(...)) (2 ops)

### ![Vector](Type-Vector.png "Vector") = ![Vector](Type-Vector.png "Vector"):setY(![Number](Type-Number.png "Number") Y)

Returns a copy of the vector with Y replaced (use as Vec = Vec:setY(...)) (2 ops)

### ![Vector](Type-Vector.png "Vector") = ![Vector](Type-Vector.png "Vector"):setZ(![Number](Type-Number.png "Number") Z)

Returns a copy of the vector with Z replaced (use as Vec = Vec:setZ(...)) (2 ops)

### ![Vector](Type-Vector.png "Vector") = round(![Vector](Type-Vector.png "Vector") Rv1)

Rounds XYZ to the nearest integer (6 ops)

### ![Vector](Type-Vector.png "Vector") = round(![Vector](Type-Vector.png "Vector") Rv1, ![Number](Type-Number.png "Number") Decimals)

Rounds XYZ to argument 2's decimal precision (6 ops)

### ![Vector](Type-Vector.png "Vector") = ceil(![Vector](Type-Vector.png "Vector") Rv1)

Rounds XYZ up to the nearest integer (6 ops)

### ![Vector](Type-Vector.png "Vector") = ceil(![Vector](Type-Vector.png "Vector") Rv1, ![Number](Type-Number.png "Number") Decimals)

Rounds XYZ up to argument 2's decimal precision (6 ops)

### ![Vector](Type-Vector.png "Vector") = floor(![Vector](Type-Vector.png "Vector") Rv1)

Rounds XYZ down to the nearest integer (6 ops)

### ![Vector](Type-Vector.png "Vector") = floor(![Vector](Type-Vector.png "Vector") Rv1, ![Number](Type-Number.png "Number") Decimals)

Rounds XYZ down to argument 2's decimal precision (6 ops)

### ![Vector](Type-Vector.png "Vector") = min(![Vector](Type-Vector.png "Vector") Vec1, ![Vector](Type-Vector.png "Vector") Vec2)

Returns the vector with the smallest length (10 ops)

### ![Vector](Type-Vector.png "Vector") = max(![Vector](Type-Vector.png "Vector") Vec1, ![Vector](Type-Vector.png "Vector") Vec2)

Returns the vector with the greatest length (10 ops)

### ![Vector](Type-Vector.png "Vector") = maxVec(![Vector](Type-Vector.png "Vector") Rv1, ![Vector](Type-Vector.png "Vector") Rv2)

Returns the vector combining the highest value components of V1 and V2 (10 ops)

### ![Vector](Type-Vector.png "Vector") = minVec(![Vector](Type-Vector.png "Vector") Rv1, ![Vector](Type-Vector.png "Vector") Rv2)

Returns a vector combining the lowest value components of V1 and V2 (10 ops)

### ![Vector](Type-Vector.png "Vector") = mod(![Vector](Type-Vector.png "Vector") Rv1, ![Number](Type-Number.png "Number") Rv2)

Returns the remainder after XYZ have been divided by argument 2 (10 ops)

### ![Vector](Type-Vector.png "Vector") = mod(![Vector](Type-Vector.png "Vector") Rv1, ![Vector](Type-Vector.png "Vector") Rv2)

Returns the remainder after the components of vector 1 have been divided by the components of vector 2 (10 ops)

### ![Vector](Type-Vector.png "Vector") = clamp(![Vector](Type-Vector.png "Vector") Value, ![Vector](Type-Vector.png "Vector") Min, ![Vector](Type-Vector.png "Vector") Max)

Clamps vector 1's XYZ between the XYZ of vector 2(min) and vector 3(max) (10 ops)

### ![Vector](Type-Vector.png "Vector") = lerp(![Vector](Type-Vector.png "Vector") From, ![Vector](Type-Vector.png "Vector") To, ![Number](Type-Number.png "Number") Fraction)

Performs linear interpolation. Returns a new value between 'from' and 'to', based on a 0-1 percentage ('fraction') (10 ops)

### ![Vector](Type-Vector.png "Vector") = mix(![Vector](Type-Vector.png "Vector") To, ![Vector](Type-Vector.png "Vector") From, ![Number](Type-Number.png "Number") Fraction)

Combines vector 1's XYZ with vector 2's XYZ by a proportion given by argument 3 (between 0 and 1) (10 ops)

### ![Vector](Type-Vector.png "Vector") = bezier(![Vector](Type-Vector.png "Vector") Startvec, ![Vector](Type-Vector.png "Vector") Tangent, ![Vector](Type-Vector.png "Vector") Endvec, ![Number](Type-Number.png "Number") Ratio)

Returns the 3D vector position on the bezier curve between the starting and ending 3D vector, given by the ratio (value between 0 and 1) (10 ops)

### ![Vector](Type-Vector.png "Vector") = bezier(![Vector](Type-Vector.png "Vector") Startvec, ![Vector](Type-Vector.png "Vector") Tangent1, ![Vector](Type-Vector.png "Vector") Tangent2, ![Vector](Type-Vector.png "Vector") Endvec, ![Number](Type-Number.png "Number") Ratio)

Returns the 3D vector position on the bezier curve between the starting and ending 3D vector, given by the ratio (value between 0 and 1) (10 ops)

### ![Vector](Type-Vector.png "Vector") = shiftR(![Vector](Type-Vector.png "Vector") Vec)

Shifts the vector's components right: shiftR( x,y,z ) = ( z,x,y ) (2 ops)

### ![Vector](Type-Vector.png "Vector") = shiftL(![Vector](Type-Vector.png "Vector") Vec)

Shifts the vector's components left: shiftL( x,y,z ) = ( y,z,x ) (2 ops)

### ![Number](Type-Number.png "Number") = inrange(![Vector](Type-Vector.png "Vector") Vec, ![Vector](Type-Vector.png "Vector") Min, ![Vector](Type-Vector.png "Vector") Max)

Returns 1 if each component of V is between (or is equal to) the components of Vmin and Vmax (5 ops)

### ![Angle](Type-Angle.png "Angle") = ![Vector](Type-Vector.png "Vector"):toAngle()

Converts a direction vector into an angle (3 ops)

### ![Angle](Type-Angle.png "Angle") = ![Vector](Type-Vector.png "Vector"):toAngle(![Vector](Type-Vector.png "Vector") Up)

Converts a direction vector into an angle with roll being determined by the up vector (3 ops)

### ![Number](Type-Number.png "Number") = pointHasContent(![Vector](Type-Vector.png "Vector") Point, ![String](Type-String.png "String") Has)

'S' can be a string containing the last half of the CONTENTS_ enums (ie without the "CONTENTS_"). Multiple CONTENTS types can be seperated by a comma. Check: Enumeration_List:Contents for a full list. Examples: "water,solid" or "empty,transparent". The function returns 1 if any one of the types are found in the vector point (20 ops)

### ![String](Type-String.png "String") = pointContents(![Vector](Type-Vector.png "Vector") Point)

Returns a string with all the "content" types in the vector point, seperated by commas (15 ops)

### ![Array](Type-Array.png "Array") = pointContentsArray(![Vector](Type-Vector.png "Vector") Point)

Returns an array with all the "content" types in the vector point (15 ops)

### ![Vector](Type-Vector.png "Vector") = toWorld(![Vector](Type-Vector.png "Vector") Localpos, ![Angle](Type-Angle.png "Angle") Localang, ![Vector](Type-Vector.png "Vector") Worldpos, ![Angle](Type-Angle.png "Angle") Worldang)

Converts a local position/angle to a world position/angle and returns the position (15 ops)

### ![Angle](Type-Angle.png "Angle") = toWorldAng(![Vector](Type-Vector.png "Vector") Localpos, ![Angle](Type-Angle.png "Angle") Localang, ![Vector](Type-Vector.png "Vector") Worldpos, ![Angle](Type-Angle.png "Angle") Worldang)

Converts a local position/angle to a world position/angle and returns the angle (15 ops)

### ![Array](Type-Array.png "Array") = toWorldPosAng(![Vector](Type-Vector.png "Vector") Localpos, ![Angle](Type-Angle.png "Angle") Localang, ![Vector](Type-Vector.png "Vector") Worldpos, ![Angle](Type-Angle.png "Angle") Worldang)

Converts a local position/angle to a world position/angle and returns both in an array (15 ops)

### ![Vector](Type-Vector.png "Vector") = toLocal(![Vector](Type-Vector.png "Vector") Localpos, ![Angle](Type-Angle.png "Angle") Localang, ![Vector](Type-Vector.png "Vector") Worldpos, ![Angle](Type-Angle.png "Angle") Worldang)

Converts a world position/angle to a local position/angle and returns the position (15 ops)

### ![Angle](Type-Angle.png "Angle") = toLocalAng(![Vector](Type-Vector.png "Vector") Localpos, ![Angle](Type-Angle.png "Angle") Localang, ![Vector](Type-Vector.png "Vector") Worldpos, ![Angle](Type-Angle.png "Angle") Worldang)

Converts a world position/angle to a local position/angle and returns the angle (15 ops)

### ![Array](Type-Array.png "Array") = toLocalPosAng(![Vector](Type-Vector.png "Vector") Localpos, ![Angle](Type-Angle.png "Angle") Localang, ![Vector](Type-Vector.png "Vector") Worldpos, ![Angle](Type-Angle.png "Angle") Worldang)

Converts a world position/angle to a local position/angle and returns both in an array (15 ops)

### ![Number](Type-Number.png "Number") = bearing(![Vector](Type-Vector.png "Vector") Originpos, ![Angle](Type-Angle.png "Angle") Originangle, ![Vector](Type-Vector.png "Vector") Pos)

Gets the bearing from the first position, at the specified angle, to the second position (15 ops)

### ![Number](Type-Number.png "Number") = elevation(![Vector](Type-Vector.png "Vector") Originpos, ![Angle](Type-Angle.png "Angle") Originangle, ![Vector](Type-Vector.png "Vector") Pos)

Gets the elevation from the first position, at the specified angle, to the second position (15 ops)

### ![Angle](Type-Angle.png "Angle") = heading(![Vector](Type-Vector.png "Vector") Originpos, ![Angle](Type-Angle.png "Angle") Originangle, ![Vector](Type-Vector.png "Vector") Pos)

Gets the elevation and bearing from the first position, at the specified angle, to the second position (15 ops)

### ![Number](Type-Number.png "Number") = ![Vector](Type-Vector.png "Vector"):isInWorld()

Returns 1 if the position vector is within the world, 0 if not (10 ops)

### ![String](Type-String.png "String") = ![Vector](Type-Vector.png "Vector"):toString()

Gets the vector nicely formatted as a string "[X,Y,Z]" (5 ops)

### ![String](Type-String.png "String") = toString(![Vector](Type-Vector.png "Vector") V)

Gets the vector nicely formatted as a string "[X,Y,Z]" (5 ops)
