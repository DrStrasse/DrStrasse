[Jump to table of contents](#default-extensions)

# Selfaware

### ![Entity](Type-Entity.png "Entity") = entity()

Gets the entity of the expression (1 ops)

### ![Entity](Type-Entity.png "Entity") = owner()

Gets the owner of the expression ( same as entity():owner() ) (1 ops)

### selfDestruct()

Removes the expression (5 ops)

### selfDestructAll()

Removes the expression and all constrained props (5 ops)

### ![Array](Type-Array.png "Array") = ioOutputEntities(![String](Type-String.png "String") Output)

Returns an array of all entities wired to the output S (10 ops)

### ![Entity](Type-Entity.png "Entity") = ioInputEntity(![String](Type-String.png "String") Input)

Returns the entity the input S is wired to (10 ops)

### Collision = ioSetOutput(![String](Type-String.png "String"), Collision)

Trigger the output S of the E2 with the collision value (3 ops)

### ![Vector](Type-Vector.png "Vector") = ioSetOutput(![String](Type-String.png "String"), ![Vector](Type-Vector.png "Vector"))

Trigger the output S of the E2 with the vector value (3 ops)

### Usercmd = ioSetOutput(![String](Type-String.png "String"), Usercmd)

Trigger the output S of the E2 with the usercmd value (3 ops)

### ![Vector4](Type-Vector4.png "Vector4") = ioSetOutput(![String](Type-String.png "String"), ![Vector4](Type-Vector4.png "Vector4"))

Trigger the output S of the E2 with the vector4 value (3 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = ioSetOutput(![String](Type-String.png "String"), ![Quaternion](Type-Quaternion.png "Quaternion"))

Trigger the output S of the E2 with the quaternion value (3 ops)

### Movedata = ioSetOutput(![String](Type-String.png "String"), Movedata)

Trigger the output S of the E2 with the movedata value (3 ops)

### ![Array](Type-Array.png "Array") = ioSetOutput(![String](Type-String.png "String"), ![Array](Type-Array.png "Array"))

Trigger the output S of the E2 with the array value (3 ops)

### ![Vector2](Type-Vector2.png "Vector2") = ioSetOutput(![String](Type-String.png "String"), ![Vector2](Type-Vector2.png "Vector2"))

Trigger the output S of the E2 with the vector2 value (3 ops)

### ![Bone](Type-Bone.png "Bone") = ioSetOutput(![String](Type-String.png "String"), ![Bone](Type-Bone.png "Bone"))

Trigger the output S of the E2 with the bone value (3 ops)

### ![Angle](Type-Angle.png "Angle") = ioSetOutput(![String](Type-String.png "String"), ![Angle](Type-Angle.png "Angle"))

Trigger the output S of the E2 with the angle value (3 ops)

### Egpobject = ioSetOutput(![String](Type-String.png "String"), Egpobject)

Trigger the output S of the E2 with the egpobject value (3 ops)

### ![Table](Type-Table.png "Table") = ioSetOutput(![String](Type-String.png "String"), ![Table](Type-Table.png "Table"))

Trigger the output S of the E2 with the table value (3 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = ioSetOutput(![String](Type-String.png "String"), ![Matrix4](Type-Matrix2.png "Matrix2"))

Trigger the output S of the E2 with the matrix2 value (3 ops)

### Effect = ioSetOutput(![String](Type-String.png "String"), Effect)

Trigger the output S of the E2 with the effect value (3 ops)

### ![Entity](Type-Entity.png "Entity") = ioSetOutput(![String](Type-String.png "String"), ![Entity](Type-Entity.png "Entity"))

Trigger the output S of the E2 with the entity value (3 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ioSetOutput(![String](Type-String.png "String"), ![Matrix](Type-Matrix.png "Matrix"))

Trigger the output S of the E2 with the matrix value (3 ops)

### Function = ioSetOutput(![String](Type-String.png "String"), Function)

Trigger the output S of the E2 with the function value (3 ops)

### ![Number](Type-Number.png "Number") = ioSetOutput(![String](Type-String.png "String"), ![Number](Type-Number.png "Number"))

Trigger the output S of the E2 with the number value (3 ops)

### ![RangerData](Type-RangerData.png "RangerData") = ioSetOutput(![String](Type-String.png "String"), ![RangerData](Type-RangerData.png "RangerData"))

Trigger the output S of the E2 with the ranger value (3 ops)

### ![WireLink](Type-WireLink.png "WireLink") = ioSetOutput(![String](Type-String.png "String"), ![WireLink](Type-WireLink.png "WireLink"))

Trigger the output S of the E2 with the wirelink value (3 ops)

### ![String](Type-String.png "String") = ioSetOutput(![String](Type-String.png "String"), ![String](Type-String.png "String"))

Trigger the output S of the E2 with the string value (3 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ioSetOutput(![String](Type-String.png "String"), ![Matrix4](Type-Matrix4.png "Matrix4"))

Trigger the output S of the E2 with the matrix4 value (3 ops)

### ![ComplexNumber](Type-ComplexNumber.png "ComplexNumber") = ioSetOutput(![String](Type-String.png "String"), ![ComplexNumber](Type-ComplexNumber.png "ComplexNumber"))

Trigger the output S of the E2 with the complex value (3 ops)

### Damage = ioSetOutput(![String](Type-String.png "String"), Damage)

Trigger the output S of the E2 with the damage value (3 ops)

### ![Entity](Type-Entity.png "Entity") = ioGetInputEntity(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Angle](Type-Angle.png "Angle") = ioGetInputAngle(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Array](Type-Array.png "Array") = ioGetInputArray(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![String](Type-String.png "String") = ioGetInputString(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### Collision = ioGetInputCollision(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![ComplexNumber](Type-ComplexNumber.png "ComplexNumber") = ioGetInputComplex(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ioGetInputMatrix(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### Damage = ioGetInputDamage(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Vector2](Type-Vector2.png "Vector2") = ioGetInputVector2(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### Movedata = ioGetInputMovedata(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### Function = ioGetInputFunction(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = ioGetInputMatrix2(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = ioGetInputQuaternion(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Number](Type-Number.png "Number") = ioGetInputNumber(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![RangerData](Type-RangerData.png "RangerData") = ioGetInputRanger(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Vector4](Type-Vector4.png "Vector4") = ioGetInputVector4(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![WireLink](Type-WireLink.png "WireLink") = ioGetInputWirelink(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### Effect = ioGetInputEffect(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### Usercmd = ioGetInputUsercmd(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### Egpobject = ioGetInputEgpobject(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ioGetInputMatrix4(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Vector](Type-Vector.png "Vector") = ioGetInputVector(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Bone](Type-Bone.png "Bone") = ioGetInputBone(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### ![Table](Type-Table.png "Table") = ioGetInputTable(![String](Type-String.png "String"))

Get the value of the input S of the E2 (3 ops)

### setName(![String](Type-String.png "String") Name)

Set the name of the E2 (100 ops)

### ![Entity](Type-Entity.png "Entity"):setName(![String](Type-String.png "String") Name)

Set the name of another E2 or component name for other entities (100 ops)

### setOverlayText(![String](Type-String.png "String") Text)

Set the overlay text of the E2 (25 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):getName()

Get the name of another E2, compatible entity or wiremod component name (5 ops)

### ![Number](Type-Number.png "Number") = canSetName()

 (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canSetName()

 (5 ops)

### ![Number](Type-Number.png "Number") = canSetName(![String](Type-String.png "String") Name)

 (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):canSetName(![String](Type-String.png "String") Name)

 (5 ops)

### ![Array](Type-Array.png "Array") = getExtensions()

Returns an array of all the extensions that the server has. This includes disabled extensions! (30 ops)

### ![Table](Type-Table.png "Table") = getExtensionStatus()

Returns a table of extension names with their statuses (60 ops)

### ![Number](Type-Number.png "Number") = getExtensionStatus(![String](Type-String.png "String") Extension)

Returns 1 if the extension is enabled, otherwise 0 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Number](Type-Number.png "Number") Value)

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![String](Type-String.png "String"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Bone](Type-Bone.png "Bone"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![WireLink](Type-WireLink.png "WireLink"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Entity](Type-Entity.png "Entity"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Vector](Type-Vector.png "Vector") Value)

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Angle](Type-Angle.png "Angle"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Vector4](Type-Vector4.png "Vector4") Value)

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(Gtable)

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Matrix4](Type-Matrix4.png "Matrix4"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Quaternion](Type-Quaternion.png "Quaternion"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Matrix4](Type-Matrix2.png "Matrix2"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(Damage)

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![RangerData](Type-RangerData.png "RangerData"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(Function)

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Matrix](Type-Matrix.png "Matrix"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(Collision)

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![Vector2](Type-Vector2.png "Vector2"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(Usercmd)

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(Movedata)

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(![ComplexNumber](Type-ComplexNumber.png "ComplexNumber"))

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(Egpobject)

 (5 ops)

### ![Number](Type-Number.png "Number") = changed(Effect)

 (5 ops)

### ![Number](Type-Number.png "Number") = hash()

Returns a numerical hash using the code of the E2 itself (Including comments) (5 ops)

### ![Number](Type-Number.png "Number") = hashNoComments()

Returns a numerical hash using the code of the E2 itself (Excluding comments) (5 ops)

### ![Number](Type-Number.png "Number") = hash(![String](Type-String.png "String") Str)

Returns the CRC-32 of the string specified. This should not be used as a legitimate hash function (5 ops)
