[Jump to table of contents](#default-extensions)

# Matrix

### ![Matrix4](Type-Matrix2.png "Matrix2") = matrix2()

Creates a 2x2 zero matrix (1 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = matrix2(![Vector2](Type-Vector2.png "Vector2") Rv1, ![Vector2](Type-Vector2.png "Vector2") Rv2)

Creates a matrix with vectors by columns (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = rowMatrix2(![Vector2](Type-Vector2.png "Vector2") Rv1, ![Vector2](Type-Vector2.png "Vector2") Rv2)

Creates a 2x2 matrix with 2D vectors by rows (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = matrix2(![Number](Type-Number.png "Number") Rv1, ![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4)

Creates a matrix with values in order (i.j) of: (1,1), (1,2), (2,1), (2,2) (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = matrix2(![Matrix](Type-Matrix.png "Matrix") Rv1)

Converts a 3x3 matrix into a 2x2 matrix - all (i,3) and (3,j) are omitted (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = identity2()

Creates a 2x2 identity matrix (5 ops)

### ![Vector2](Type-Vector2.png "Vector2") = ![Matrix4](Type-Matrix2.png "Matrix2"):row(![Number](Type-Number.png "Number") Rv2)

Returns the row as a 2D vector (5 ops)

### ![Vector2](Type-Vector2.png "Vector2") = ![Matrix4](Type-Matrix2.png "Matrix2"):column(![Number](Type-Number.png "Number") Rv2)

Returns the column as a 2D vector (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = ![Matrix4](Type-Matrix2.png "Matrix2"):setRow(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4)

Sets the values of a row. The first argument given specifies the row(j), the following arguments are the values 1j, 2j (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = ![Matrix4](Type-Matrix2.png "Matrix2"):setRow(![Number](Type-Number.png "Number") Rv2, ![Vector2](Type-Vector2.png "Vector2") Rv3)

Sets the values of a row. The first argument given specifies the row, the vector contains the values to set (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = ![Matrix4](Type-Matrix2.png "Matrix2"):setColumn(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4)

Sets the values of a column. The first argument given specifies the column(i), the following arguments are the values i1, i2 (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = ![Matrix4](Type-Matrix2.png "Matrix2"):setColumn(![Number](Type-Number.png "Number") Rv2, ![Vector2](Type-Vector2.png "Vector2") Rv3)

Sets the values of a column. The first argument given specifies the column, the vector contains the values to set (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = ![Matrix4](Type-Matrix2.png "Matrix2"):swapRows()

Swaps rows (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = ![Matrix4](Type-Matrix2.png "Matrix2"):swapColumns()

Swaps columns (5 ops)

### ![Number](Type-Number.png "Number") = ![Matrix4](Type-Matrix2.png "Matrix2"):element(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3)

Returns the element with indices (i,j) (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = ![Matrix4](Type-Matrix2.png "Matrix2"):setElement(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4)

Sets an element's value. The first two arguments specify the indices (i,j), the third argument is the value to set it to (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = ![Matrix4](Type-Matrix2.png "Matrix2"):swapElements(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4, ![Number](Type-Number.png "Number") Rv5)

Swaps two elements, specified by indices ( i1, j1, i2, j2 ) (5 ops)

### ![Vector2](Type-Vector2.png "Vector2") = diagonal(![Matrix4](Type-Matrix2.png "Matrix2") Rv1)

Returns a 2D vector comprising the elements along the leading diagonal (5 ops)

### ![Number](Type-Number.png "Number") = trace(![Matrix4](Type-Matrix2.png "Matrix2") Rv1)

Returns the trace of a matrix (5 ops)

### ![Number](Type-Number.png "Number") = det(![Matrix4](Type-Matrix2.png "Matrix2") Rv1)

Returns the determinant of a matrix (Does not work for 4x4 matrices) (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = transpose(![Matrix4](Type-Matrix2.png "Matrix2") Rv1)

Returns the transpose of a matrix (5 ops)

### ![Matrix4](Type-Matrix2.png "Matrix2") = adj(![Matrix4](Type-Matrix2.png "Matrix2") Rv1)

Returns the adjugate of a matrix (Does not work for 4x4 matrices) (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = matrix()

Creates a 3x3 zero matrix (1 ops)

### ![Matrix](Type-Matrix.png "Matrix") = matrix(![Vector](Type-Vector.png "Vector") Rv1, ![Vector](Type-Vector.png "Vector") Rv2, ![Vector](Type-Vector.png "Vector") Rv3)

Creates a matrix with vectors by columns (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = rowMatrix(![Vector](Type-Vector.png "Vector") Rv1, ![Vector](Type-Vector.png "Vector") Rv2, ![Vector](Type-Vector.png "Vector") Rv3)

Creates a 3x3 matrix with vectors by rows (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = matrix(![Number](Type-Number.png "Number") Rv1, ![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4, ![Number](Type-Number.png "Number") Rv5, ![Number](Type-Number.png "Number") Rv6, ![Number](Type-Number.png "Number") Rv7, ![Number](Type-Number.png "Number") Rv8, ![Number](Type-Number.png "Number") Rv9)

Creates a matrix with 9 values in the following order (i.j): (1,1), (1,2), (1,3), (2,1) etc (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = matrix(![Matrix4](Type-Matrix2.png "Matrix2") Rv1)

Converts a 2x2 matrix into a 3x3 matrix - all (i,3) and (3,j) are filled with 0's (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = identity()

Creates a 3x3 identity matrix (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Matrix](Type-Matrix.png "Matrix"):row(![Number](Type-Number.png "Number") Rv2)

Returns the row as a vector (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Matrix](Type-Matrix.png "Matrix"):column(![Number](Type-Number.png "Number") Rv2)

Returns the column as a vector (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix](Type-Matrix.png "Matrix"):setRow(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4, ![Number](Type-Number.png "Number") Rv5)

Sets the values of a row. The first argument given specifies the row(j), the following arguments are the values 1j, 2j, 3j (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix](Type-Matrix.png "Matrix"):setRow(![Number](Type-Number.png "Number") Rv2, ![Vector](Type-Vector.png "Vector") Rv3)

Sets the values of a row. The first argument given specifies the row, the vector contains the values to set (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix](Type-Matrix.png "Matrix"):setColumn(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4, ![Number](Type-Number.png "Number") Rv5)

Sets the values of a column. The first argument given specifies the column(i), the following arguments are the values i1, i2, i3 (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix](Type-Matrix.png "Matrix"):setColumn(![Number](Type-Number.png "Number") Rv2, ![Vector](Type-Vector.png "Vector") Rv3)

Sets the values of a column. The first argument given specifies the column, the vector contains the values to set (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix](Type-Matrix.png "Matrix"):swapColumns(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3)

Swaps the two columns specified (5 ops)

### ![Number](Type-Number.png "Number") = ![Matrix](Type-Matrix.png "Matrix"):element(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3)

Returns the element with indices (i,j) (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix](Type-Matrix.png "Matrix"):setElement(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4)

Sets an element's value. The first two arguments specify the indices (i,j), the third argument is the value to set it to (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix](Type-Matrix.png "Matrix"):swapElements(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4, ![Number](Type-Number.png "Number") Rv5)

Swaps two elements, specified by indices ( i1, j1, i2, j2 ) (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix](Type-Matrix.png "Matrix"):setDiagonal(![Vector](Type-Vector.png "Vector") Rv2)

Sets the elements of the leading diagonal from the components of a vector (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix](Type-Matrix.png "Matrix"):setDiagonal(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4)

Sets the elements of the leading diagonal (5 ops)

### ![Vector](Type-Vector.png "Vector") = diagonal(![Matrix](Type-Matrix.png "Matrix") Rv1)

Returns a vector comprising the elements along the leading diagonal (5 ops)

### ![Number](Type-Number.png "Number") = trace(![Matrix](Type-Matrix.png "Matrix") Rv1)

Returns the trace of a matrix (5 ops)

### ![Number](Type-Number.png "Number") = det(![Matrix](Type-Matrix.png "Matrix") Rv1)

Returns the determinant of a matrix (Does not work for 4x4 matrices) (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = transpose(![Matrix](Type-Matrix.png "Matrix") Rv1)

Returns the transpose of a matrix (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = adj(![Matrix](Type-Matrix.png "Matrix") Rv1)

Returns the adjugate of a matrix (Does not work for 4x4 matrices) (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = matrix(![Entity](Type-Entity.png "Entity") Rv1)

Creates a reference frame matrix from an entity's local direction vectors by columns in the order ( x, y, z ) (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Matrix](Type-Matrix.png "Matrix"):x()

Returns the local x direction vector from a 3x3 coordinate reference frame matrix ( same as M:column(1) ) (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Matrix](Type-Matrix.png "Matrix"):y()

Returns the local y direction vector from a 3x3 coordinate reference frame matrix ( same as M:column(2) ) (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Matrix](Type-Matrix.png "Matrix"):z()

Returns the local z direction vector from a 3x3 coordinate reference frame matrix ( same as M:column(3) ) (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = matrix(![Angle](Type-Angle.png "Angle") Ang)

Returns a 3x3 reference frame matrix as described by the angle A. Multiplying by this matrix will be the same as rotating by the given angle (5 ops)

### ![Angle](Type-Angle.png "Angle") = ![Matrix](Type-Matrix.png "Matrix"):toAngle()

Returns an angle derived from a 3x3 rotation matrix (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = mRotation(![Vector](Type-Vector.png "Vector") Rv1, ![Number](Type-Number.png "Number") Rv2)

Creates a 3x3 rotation matrix, where the vector is the axis of rotation, and the number is the angle (anti-clockwise) in degrees. Example*: to rotate a vector (7,8,9) by 50 degrees about the axis (1,1,0), you would write V = mRotation(vec(1,1,0), 50) * vec(7,8,9) (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = matrix4()

Creates a 4x4 zero matrix (1 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = matrix4(![Vector4](Type-Vector4.png "Vector4") Rv1, ![Vector4](Type-Vector4.png "Vector4") Rv2, ![Vector4](Type-Vector4.png "Vector4") Rv3, ![Vector4](Type-Vector4.png "Vector4") Rv4)

Creates a matrix with vectors by columns (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = rowMatrix4(![Vector4](Type-Vector4.png "Vector4") Rv1, ![Vector4](Type-Vector4.png "Vector4") Rv2, ![Vector4](Type-Vector4.png "Vector4") Rv3, ![Vector4](Type-Vector4.png "Vector4") Rv4)

Creates a 4x4 matrix with 4D vectors by rows (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = matrix4(![Number](Type-Number.png "Number") Rv1, ![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4, ![Number](Type-Number.png "Number") Rv5, ![Number](Type-Number.png "Number") Rv6, ![Number](Type-Number.png "Number") Rv7, ![Number](Type-Number.png "Number") Rv8, ![Number](Type-Number.png "Number") Rv9, ![Number](Type-Number.png "Number") Rv10, ![Number](Type-Number.png "Number") Rv11, ![Number](Type-Number.png "Number") Rv12, ![Number](Type-Number.png "Number") Rv13, ![Number](Type-Number.png "Number") Rv14, ![Number](Type-Number.png "Number") Rv15, ![Number](Type-Number.png "Number") Rv16)

Creates a matrix with 16 values in the following order (i.j): (1,1), (1,2), (1,3), (1,4), (2,1) etc (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = matrix4(![Matrix4](Type-Matrix2.png "Matrix2") Rv1)

Converts a 2x2 matrix into a 4x4 matrix - all (i,3), (i,4), (3,j) and (4,j) are filled with 0's (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = matrix4(![Matrix4](Type-Matrix2.png "Matrix2") Rv1, ![Matrix4](Type-Matrix2.png "Matrix2") Rv2, ![Matrix4](Type-Matrix2.png "Matrix2") Rv3, ![Matrix4](Type-Matrix2.png "Matrix2") Rv4)

Constructs a 4x4 matrix from four 2x2 matrices (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = matrix4(![Matrix](Type-Matrix.png "Matrix") Rv1)

Converts a 3x3 matrix into a 4x4 matrix - all (i,4) and (4,j) are filled with 0's (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = identity4()

Creates a 4x4 identity matrix (5 ops)

### ![Vector4](Type-Vector4.png "Vector4") = ![Matrix4](Type-Matrix4.png "Matrix4"):row(![Number](Type-Number.png "Number") Rv2)

Returns the row as a 4D vector (5 ops)

### ![Vector4](Type-Vector4.png "Vector4") = ![Matrix4](Type-Matrix4.png "Matrix4"):column(![Number](Type-Number.png "Number") Rv2)

Returns the column as a 4D vector (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ![Matrix4](Type-Matrix4.png "Matrix4"):setRow(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4, ![Number](Type-Number.png "Number") Rv5, ![Number](Type-Number.png "Number") Rv6)

Sets the values of a row. The first argument given specifies the row(j), the following arguments are the values 1j, 2j, 3j, 4j (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ![Matrix4](Type-Matrix4.png "Matrix4"):setRow(![Number](Type-Number.png "Number") Rv2, ![Vector4](Type-Vector4.png "Vector4") Rv3)

Sets the values of a row. The first argument given specifies the row, the vector contains the values to set (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ![Matrix4](Type-Matrix4.png "Matrix4"):setColumn(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4, ![Number](Type-Number.png "Number") Rv5, ![Number](Type-Number.png "Number") Rv6)

Sets the values of a column. The first argument given specifies the column(i), the following arguments are the values i1, i2, i3, i4 (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ![Matrix4](Type-Matrix4.png "Matrix4"):setColumn(![Number](Type-Number.png "Number") Rv2, ![Vector4](Type-Vector4.png "Vector4") Rv3)

Sets the values of a column. The first argument given specifies the column, the vector contains the values to set (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix](Type-Matrix.png "Matrix"):swapRows(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3)

Swaps the two rows specified (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ![Matrix4](Type-Matrix4.png "Matrix4"):swapColumns(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3)

Swaps the two columns specified (5 ops)

### ![Number](Type-Number.png "Number") = ![Matrix4](Type-Matrix4.png "Matrix4"):element(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3)

Returns the element with indices (i,j) (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ![Matrix4](Type-Matrix4.png "Matrix4"):setElement(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4)

Sets an element's value. The first two arguments specify the indices (i,j), the third argument is the value to set it to (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ![Matrix4](Type-Matrix4.png "Matrix4"):swapElements(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4, ![Number](Type-Number.png "Number") Rv5)

Swaps two elements, specified by indices ( i1, j1, i2, j2 ) (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ![Matrix4](Type-Matrix4.png "Matrix4"):setDiagonal(![Vector4](Type-Vector4.png "Vector4") Rv2)

Sets the elements of the leading diagonal from the components of a vector (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = ![Matrix4](Type-Matrix4.png "Matrix4"):setDiagonal(![Number](Type-Number.png "Number") Rv2, ![Number](Type-Number.png "Number") Rv3, ![Number](Type-Number.png "Number") Rv4, ![Number](Type-Number.png "Number") Rv5)

Sets the elements of the leading diagonal (5 ops)

### ![Vector4](Type-Vector4.png "Vector4") = diagonal(![Matrix4](Type-Matrix4.png "Matrix4") Rv1)

Returns a 4D vector comprising the elements along the leading diagonal (5 ops)

### ![Number](Type-Number.png "Number") = trace(![Matrix4](Type-Matrix4.png "Matrix4") Rv1)

Returns the trace of a matrix (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = transpose(![Matrix4](Type-Matrix4.png "Matrix4") Rv1)

Returns the transpose of a matrix (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = inverseA(![Matrix4](Type-Matrix4.png "Matrix4") Rv1)

Finds the matrix inverse of a standard 4x4 affine transformation matrix ( the type created by matrix4(E) ). This should only be used on matrices with a particular format, where the top left 3x3 specifies rotation, the rightmost 3-column specifies translation, and the bottom row is (0,0,0,1) (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = matrix4(![Entity](Type-Entity.png "Entity") Rv1)

Creates a 4x4 reference frame matrix from an entity's local direction vectors by columns in the order (x, y, z, pos), with the bottom row (0,0,0,1) (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Matrix4](Type-Matrix4.png "Matrix4"):x()

Returns the local x direction vector from a 4x4 coordinate reference frame matrix (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Matrix4](Type-Matrix4.png "Matrix4"):y()

Returns the local y direction vector from a 4x4 coordinate reference frame matrix (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Matrix4](Type-Matrix4.png "Matrix4"):z()

Returns the local z direction vector from a 4x4 coordinate reference frame matrix (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![Matrix4](Type-Matrix4.png "Matrix4"):pos()

Returns the position vector from a 4x4 coordinate reference frame matrix (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = matrix4(![Angle](Type-Angle.png "Angle") Ang)

Returns a 4x4 reference frame matrix as described by the angle A. Multiplying by this matrix will be the same as rotating by the given angle (5 ops)

### ![Matrix4](Type-Matrix4.png "Matrix4") = matrix4(![Angle](Type-Angle.png "Angle") Ang, ![Vector](Type-Vector.png "Vector") Pos)

Returns a 4x4 reference frame matrix as described by the angle A and the position V. Multiplying by this matrix will be the same as rotating by the given angle and offsetting by the given vector (5 ops)

### ![Angle](Type-Angle.png "Angle") = ![Matrix4](Type-Matrix4.png "Matrix4"):toAngle()

 (5 ops)

### ![Matrix](Type-Matrix.png "Matrix") = ![Matrix4](Type-Matrix4.png "Matrix4"):rotationMatrix()

 (5 ops)
