[Jump to table of contents](#default-extensions)

# Quaternion

### ![Quaternion](Type-Quaternion.png "Quaternion") = quat()

Creates a zero quaternion (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = quat(![Number](Type-Number.png "Number") Real)

Creates a quaternion with real part equal to N (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = quat(![ComplexNumber](Type-ComplexNumber.png "ComplexNumber") C)

Creates a quaternion with real and "i" parts equal to C (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = quat(![Vector](Type-Vector.png "Vector") Imag)

Converts a vector to a quaternion (returns V.x*i + V.y*j + V.z*k) (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = quat(![Number](Type-Number.png "Number") Real, ![Number](Type-Number.png "Number") I, ![Number](Type-Number.png "Number") J, ![Number](Type-Number.png "Number") K)

Returns N+N2i+N3j+N4k (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = quat(![Angle](Type-Angle.png "Angle") Ang)

Converts A to a quaternion (6 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = quat(![Vector](Type-Vector.png "Vector") Forward, ![Vector](Type-Vector.png "Vector") Up)

Creates a quaternion given forward (V) and up (V2) vectors (15 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = quat(![Entity](Type-Entity.png "Entity") Ent)

Converts angle of E to a quaternion (15 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = qi()

Returns quaternion i (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = qi(![Number](Type-Number.png "Number") N)

Returns quaternion N*i (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = qj()

Returns j (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = qj(![Number](Type-Number.png "Number") N)

Returns N*j (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = qk()

Returns k (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = qk(![Number](Type-Number.png "Number") N)

Returns N*k (1 ops)

### ![Number](Type-Number.png "Number") = abs(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Returns absolute value of Q (4 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = conj(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Returns the conjugate of Q (4 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = inv(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Returns the inverse of Q (4 ops)

### ![Number](Type-Number.png "Number") = ![Quaternion](Type-Quaternion.png "Quaternion"):real()

Returns the real component of the quaternion (1 ops)

### ![Number](Type-Number.png "Number") = ![Quaternion](Type-Quaternion.png "Quaternion"):i()

Returns the i component of the quaternion (1 ops)

### ![Number](Type-Number.png "Number") = ![Quaternion](Type-Quaternion.png "Quaternion"):j()

Returns the j component of the quaternion (1 ops)

### ![Number](Type-Number.png "Number") = ![Quaternion](Type-Quaternion.png "Quaternion"):k()

Returns the k component of the quaternion (1 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = exp(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Raises Euler's constant e to the power Q (7 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = log(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Calculates natural logarithm of Q (7 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = qMod(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Changes quaternion Q so that the represented rotation is by an angle between 0 and 180 degrees (by coder0xff) (2 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = slerp(![Quaternion](Type-Quaternion.png "Quaternion") Q0, ![Quaternion](Type-Quaternion.png "Quaternion") Q1, ![Number](Type-Number.png "Number") T)

Performs spherical linear interpolation between Q and Q2. Returns Q for N=0, Q2 for N=1 (13 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = nlerp(![Quaternion](Type-Quaternion.png "Quaternion") Q0, ![Quaternion](Type-Quaternion.png "Quaternion") Q1, ![Number](Type-Number.png "Number") T)

Performs linear interpolation between Q and Q2. Returns normalized Q for N=0, Q2 for N=1. (13 ops)

### ![Vector](Type-Vector.png "Vector") = ![Quaternion](Type-Quaternion.png "Quaternion"):forward()

Returns vector pointing forward for Q (7 ops)

### ![Vector](Type-Vector.png "Vector") = ![Quaternion](Type-Quaternion.png "Quaternion"):right()

Returns vector pointing right for Q (7 ops)

### ![Vector](Type-Vector.png "Vector") = ![Quaternion](Type-Quaternion.png "Quaternion"):up()

Returns vector pointing up for Q (7 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = qRotation(![Vector](Type-Vector.png "Vector") Axis, ![Number](Type-Number.png "Number") Ang)

Returns quaternion for rotation about axis V by angle N (9 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = qRotation(![Vector](Type-Vector.png "Vector") Rv1)

Construct a quaternion from the rotation vector V. Vector direction is axis of rotation, magnitude is angle in degress (by coder0xff) (9 ops)

### ![Number](Type-Number.png "Number") = rotationAngle(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Returns the angle of rotation in degrees (by coder0xff) (9 ops)

### ![Vector](Type-Vector.png "Vector") = rotationAxis(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Returns the axis of rotation (by coder0xff) (9 ops)

### ![Vector](Type-Vector.png "Vector") = rotationVector(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Returns the rotation vector - rotation axis where magnitude is the angle of rotation in degress (by coder0xff) (9 ops)

### ![Vector](Type-Vector.png "Vector") = vec(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Converts Q to a vector by dropping the real component (3 ops)

### ![Matrix](Type-Matrix.png "Matrix") = matrix(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Converts Q to a transformation matrix (15 ops)

### ![Angle](Type-Angle.png "Angle") = ![Quaternion](Type-Quaternion.png "Quaternion"):toAngle()

Returns angle represented by Q (15 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = ![Quaternion](Type-Quaternion.png "Quaternion"):normalized()

Returns new normalized quaternion for Q (15 ops)

### ![Number](Type-Number.png "Number") = ![Quaternion](Type-Quaternion.png "Quaternion"):dot(![Quaternion](Type-Quaternion.png "Quaternion") Q1)

Returns dot product of Q with Q2 (15 ops)

### ![String](Type-String.png "String") = toString(![Quaternion](Type-Quaternion.png "Quaternion") Q)

Formats Q as a string (15 ops)

### ![String](Type-String.png "String") = ![Quaternion](Type-Quaternion.png "Quaternion"):toString()

Formats Q as a string (15 ops)
