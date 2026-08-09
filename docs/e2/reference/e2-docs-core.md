[Jump to table of contents](#default-extensions)

# Core

### ![Number](Type-Number.png "Number") = first()

Returns 1 if the expression was spawned or reset (1 ops)

### ![Number](Type-Number.png "Number") = duped()

Returns 1 if the expression was duplicated (1 ops)

### ![Number](Type-Number.png "Number") = inputClk()

DEPRECATED. Use 'event input(InputName:string)' instead! Returns 1 if the expression was triggered by an input (1 ops)

### ![String](Type-String.png "String") = inputClkName()

DEPRECATED. Use 'event input(InputName:string)' instead! Returns name of input that triggered an execution (1 ops)

### ![Number](Type-Number.png "Number") = last()

DEPRECATED. Use 'event removed(Resetting:number)' instead! Returns 1 if it is being called on the last execution of the expression gate before it is removed or reset. This execution must be requested with the runOnLast(1) command (1 ops)

### ![Number](Type-Number.png "Number") = dupefinished()

Returns 1 when the contraption has finished duping. (1 ops)

### ![Number](Type-Number.png "Number") = removing()

DEPRECATED. Use 'event removed(Resetting:number)' instead! Returns 1 if this is the last() execution and caused by the entity being removed (1 ops)

### runOnLast(![Number](Type-Number.png "Number") Activate)

DEPRECATED. Use 'event removed(Resetting:number)' instead! If set to 1, the chip will run once when it is removed, setting the last() flag when it does (1 ops)

### exit()

Stops the execution of any code after it (2 ops)

### error(![String](Type-String.png "String") Reason)

Shuts down the E2 with specified script error message (2 ops)

### assert(![Number](Type-Number.png "Number") Condition)

If the argument is 0, shut down the E2 with an error message (2 ops)

### assert(![Number](Type-Number.png "Number") Condition, ![String](Type-String.png "String") Reason)

If the first argument is 0, shut down the E2 with the given error message string (2 ops)

### assertSoft(![Number](Type-Number.png "Number") Condition)

Same as assert(n), but will only shutdown in @strict mode (2 ops)

### assertSoft(![Number](Type-Number.png "Number") Condition, ![String](Type-String.png "String") Reason)

Same as assert(ns), but will only shutdown in @strict mode (2 ops)

### ![Number](Type-Number.png "Number") = isStrict()

Returns 1 if the E2 is in strict mode, 0 otherwise (2 ops)

### reset()

Reset the expression itself as if it was just spawned, stops execution (100 ops)

### ![Number](Type-Number.png "Number") = ops()

Returns how many ops are used every execution on average (1 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):ops()

 (1 ops)

### ![Number](Type-Number.png "Number") = opcounter()

Returns how many ops have been used so far in this execution plus the amount of hard quota used (1 ops)

### ![Number](Type-Number.png "Number") = cpuUsage()

Returns the average time per tick the server spends running this E2, in seconds (multiply it by 1000000 to get the same value as is displayed on the E2 overlay) (1 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):cpuUsage()

Returns the average time per tick the server spends running the specified E2, in seconds (multiply it by 1000000 to get the same value as is displayed on the E2 overlay) (1 ops)

### ![Number](Type-Number.png "Number") = perf()

If used as a while loop condition, stabilizes the expression around hardquota used (1 ops)

### ![Number](Type-Number.png "Number") = perf(![Number](Type-Number.png "Number") N)

If used as a while loop condition, stabilizes the expression around specified number (in %) (1 ops)

### ![Number](Type-Number.png "Number") = minquota()

The ops left before soft quota is used up (1 ops)

### ![Number](Type-Number.png "Number") = maxquota()

The ops left before hard quota is exceeded and the expression shuts down (1 ops)

### ![Number](Type-Number.png "Number") = softQuota()

Returns the size of the soft quota (1 ops)

### ![Number](Type-Number.png "Number") = hardQuota()

Returns the size of the hard quota (1 ops)

### ![Number](Type-Number.png "Number") = timeQuota()

Returns the time quota in seconds (1 ops)

### ![Vector4](Type-Vector4.png "Vector4") = select(![Number](Type-Number.png "Number") Index, ![Vector4](Type-Vector4.png "Vector4") Argument1, ...)

Returns the Nth value given after the index, vector4's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![ComplexNumber](Type-ComplexNumber.png "ComplexNumber") = select(![Number](Type-Number.png "Number") Index, ![ComplexNumber](Type-ComplexNumber.png "ComplexNumber") Argument1, ...)

Returns the Nth value given after the index, complex's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![String](Type-String.png "String") = select(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Argument1, ...)

Returns the Nth value given after the index, string's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### Movedata = select(![Number](Type-Number.png "Number") Index, Movedata Argument1, ...)

Returns the Nth value given after the index, movedata's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### Gtable = select(![Number](Type-Number.png "Number") Index, Gtable Argument1, ...)

Returns the Nth value given after the index, gtable's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Vector2](Type-Vector2.png "Vector2") = select(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Argument1, ...)

Returns the Nth value given after the index, vector2's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![RangerData](Type-RangerData.png "RangerData") = select(![Number](Type-Number.png "Number") Index, ![RangerData](Type-RangerData.png "RangerData") Argument1, ...)

Returns the Nth value given after the index, ranger's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### Function = select(![Number](Type-Number.png "Number") Index, Function Argument1, ...)

Returns the Nth value given after the index, function's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### Egpobject = select(![Number](Type-Number.png "Number") Index, Egpobject Argument1, ...)

Returns the Nth value given after the index, egpobject's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### Effect = select(![Number](Type-Number.png "Number") Index, Effect Argument1, ...)

Returns the Nth value given after the index, effect's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Number](Type-Number.png "Number") = select(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Argument1, ...)

Returns the Nth value given after the index, number's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![WireLink](Type-WireLink.png "WireLink") = select(![Number](Type-Number.png "Number") Index, ![WireLink](Type-WireLink.png "WireLink") Argument1, ...)

Returns the Nth value given after the index, wirelink's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = select(![Number](Type-Number.png "Number") Index, ![Matrix4](Type-Matrix4.png "Matrix4") Argument1, ...)

Returns the Nth value given after the index, matrix4's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Matrix](Type-Matrix.png "Matrix") = select(![Number](Type-Number.png "Number") Index, ![Matrix](Type-Matrix.png "Matrix") Argument1, ...)

Returns the Nth value given after the index, matrix's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Entity](Type-Entity.png "Entity") = select(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Argument1, ...)

Returns the Nth value given after the index, entity's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = select(![Number](Type-Number.png "Number") Index, ![Matrix4](Type-Matrix2.png "Matrix2") Argument1, ...)

Returns the Nth value given after the index, matrix2's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### Collision = select(![Number](Type-Number.png "Number") Index, Collision Argument1, ...)

Returns the Nth value given after the index, collision's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Vector](Type-Vector.png "Vector") = select(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Argument1, ...)

Returns the Nth value given after the index, vector's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### Usercmd = select(![Number](Type-Number.png "Number") Index, Usercmd Argument1, ...)

Returns the Nth value given after the index, usercmd's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Quaternion](Type-Quaternion.png "Quaternion") = select(![Number](Type-Number.png "Number") Index, ![Quaternion](Type-Quaternion.png "Quaternion") Argument1, ...)

Returns the Nth value given after the index, quaternion's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Angle](Type-Angle.png "Angle") = select(![Number](Type-Number.png "Number") Index, ![Angle](Type-Angle.png "Angle") Argument1, ...)

Returns the Nth value given after the index, angle's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### Damage = select(![Number](Type-Number.png "Number") Index, Damage Argument1, ...)

Returns the Nth value given after the index, damage's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Table](Type-Table.png "Table") = select(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Argument1, ...)

Returns the Nth value given after the index, table's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Array](Type-Array.png "Array") = select(![Number](Type-Number.png "Number") Index, ![Array](Type-Array.png "Array") Argument1, ...)

Returns the Nth value given after the index, array's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)

### ![Bone](Type-Bone.png "Bone") = select(![Number](Type-Number.png "Number") Index, ![Bone](Type-Bone.png "Bone") Argument1, ...)

Returns the Nth value given after the index, bone's zero element otherwise. If you mix types, the behaviour is undefined (15 ops)
