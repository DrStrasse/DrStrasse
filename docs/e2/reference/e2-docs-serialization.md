[Jump to table of contents](#default-extensions)

# Serialization

### ![String](Type-String.png "String") = vonEncode(![Table](Type-Table.png "Table") Data)

Encodes a table into a string using vON (10 ops)

### ![String](Type-String.png "String") = vonEncode(![Array](Type-Array.png "Array") Data)

Encodes an array into a string using vON (10 ops)

### ![Array](Type-Array.png "Array") = vonDecode(![String](Type-String.png "String") Data)

Decodes a string into an array using vON (10 ops)

### ![String](Type-String.png "String") = vonError()

Returns the last von error (1 ops)

### ![Table](Type-Table.png "Table") = vonDecodeTable(![String](Type-String.png "String") Data)

Decodes a string into a table using vON (25 ops)

### ![String](Type-String.png "String") = jsonError()

Returns the last json error (1 ops)

### ![String](Type-String.png "String") = jsonEncode(![Table](Type-Table.png "Table") Data)

Encodes a table into a string using json (50 ops)

### ![String](Type-String.png "String") = jsonEncode(![Table](Type-Table.png "Table") Data, ![Number](Type-Number.png "Number") Prettyprint)

Encodes a table into a string using json (50 ops)

### ![Table](Type-Table.png "Table") = jsonDecode(![String](Type-String.png "String") Data)

Decodes a string into an array using json (50 ops)
