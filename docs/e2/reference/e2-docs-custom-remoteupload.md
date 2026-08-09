[Jump to table of contents](#default-extensions)

# Custom/remoteupload

### ![Entity](Type-Entity.png "Entity"):remoteUpload(![String](Type-String.png "String") Filepath)

Uploads the code from your computer to the server (1000 ops)

### ![Entity](Type-Entity.png "Entity"):remoteSetCode(![String](Type-String.png "String") Code)

Sets the E2's code with main file (250 ops)

### ![Entity](Type-Entity.png "Entity"):remoteSetCode(![String](Type-String.png "String") Main, ![Table](Type-Table.png "Table") Includes)

Sets the E2's code with main file & includes (250 ops)

### ![String](Type-String.png "String") = getCode()

Returns the code of the E2 as a string (20 ops)

### ![Table](Type-Table.png "Table") = getCodeIncludes()

Returns a table where indices (keys) are names of included files and entries are their codes (20 ops)
