[Jump to table of contents](#default-extensions)

# Constraint

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):getConstraints()

Returns an array with all entities directly or indirectly constrained to E, except E itself. Deprecated, use E:getConnectedEntities(...) instead. (20 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):getConnectedEntities(...)

Returns an array with all entities directly or indirectly constrained or parented to E, including E itself. (20 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):getConnectedEntities(![Array](Type-Array.png "Array") Filters)

Returns an array with all entities directly or indirectly constrained or parented to E, including E itself. (20 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):hasConstraints()

Returns the number of the constraints E has (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):hasConstraints(![String](Type-String.png "String") Constrainttype)

Returns the number of the constraints E has with the given constraint type (5 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):isConstrained()

Returns 1 if E has constraints, 0 if not (5 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):isWeldedTo()

Returns the first entity E was welded to (5 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):isWeldedTo(![Number](Type-Number.png "Number") Index)

Returns the Nth entity E was welded to (5 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):isConstrainedTo()

Returns the first entity E was constrained to (5 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):isConstrainedTo(![Number](Type-Number.png "Number") Index)

Returns the Nth entity E was constrained to (5 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):isConstrainedTo(![String](Type-String.png "String") Constrainttype)

Returns the first entity E was constrained to with the given constraint type (see the types list below) (5 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):isConstrainedTo(![String](Type-String.png "String") Constrainttype, ![Number](Type-Number.png "Number") Index)

Returns the Nth entity E was constrained to with the given constraint type (see the types list below) (5 ops)

### ![Entity](Type-Entity.png "Entity") = ![Entity](Type-Entity.png "Entity"):parent()

Returns the entity E is parented to (5 ops)

### ![Bone](Type-Bone.png "Bone") = ![Entity](Type-Entity.png "Entity"):parentBone()

Returns the bone E is parented to (5 ops)

### ![Array](Type-Array.png "Array") = ![Entity](Type-Entity.png "Entity"):children()

Returns an array containing all the children of the entity - that is, every entity whose parent is this entity (20 ops)
