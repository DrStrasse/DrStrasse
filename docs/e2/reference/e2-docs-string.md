[Jump to table of contents](#default-extensions)

# String

### ![Number](Type-Number.png "Number") = ![String](Type-String.png "String"):toNumber()

Parses a number from a string (2 ops)

### ![Number](Type-Number.png "Number") = ![String](Type-String.png "String"):toNumber(![Number](Type-Number.png "Number") Base)

Parses a number from a string. The argument given is the base. I.e. toNumber(16) will parse hex (2 ops)

### ![String](Type-String.png "String") = toChar(![Number](Type-Number.png "Number") N)

Returns a one-character string from it's ASCII code, where 32 = argument 1 = 255. An empty string is returned for numbers outside that range (1 ops)

### ![Number](Type-Number.png "Number") = toByte(![String](Type-String.png "String") C)

Returns the ASCII code of the 1st character in the string (1 ops)

### ![Number](Type-Number.png "Number") = toByte(![String](Type-String.png "String") Str, ![Number](Type-Number.png "Number") Idx)

Returns the ASCII code of the Nth character in the string (1 ops)

### ![String](Type-String.png "String") = toUnicodeChar(![Number](Type-Number.png "Number") Byte)

Returns a one-character string from it's UNICODE code (5 ops)

### ![Number](Type-Number.png "Number") = toUnicodeByte(![String](Type-String.png "String") C)

Returns the Unicode code of the 1st character in the string (5 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):index(![Number](Type-Number.png "Number") Idx)

Returns Nth letter of the string, formatted as a string (1 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):left(![Number](Type-Number.png "Number") Idx)

Returns N amount of characters starting from the leftmost character (1 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):right(![Number](Type-Number.png "Number") Idx)

Returns N amount of characters starting from the rightmost character (1 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):sub(![Number](Type-Number.png "Number") Start, ![Number](Type-Number.png "Number") Finish)

Returns a substring, starting at the first number argument and ending at the second (1 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):sub(![Number](Type-Number.png "Number") Start)

Returns a substring, starting at the number argument and ending at the end of the string (1 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):upper()

All characters are made uppercase (1 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):lower()

All characters are made lowercase (1 ops)

### ![Number](Type-Number.png "Number") = ![String](Type-String.png "String"):length()

Returns the length of the string (1 ops)

### ![Number](Type-Number.png "Number") = ![String](Type-String.png "String"):unicodeLength()

Returns the unicode length of the string (10 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):repeat(![Number](Type-Number.png "Number") Times)

Repeats the input string N times (3 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):trim()

Trims away spaces at the beginning and end of a string (2 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):trimLeft()

Trims away opening spaces on the string (2 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):trimRight()

Trims away spaces at the end of a string (2 ops)

### ![Number](Type-Number.png "Number") = ![String](Type-String.png "String"):findRE(![String](Type-String.png "String") Pattern)

Returns the 1st occurrence of the string S using REGEX functions, returns 0 if not found (10 ops)

### ![Number](Type-Number.png "Number") = ![String](Type-String.png "String"):findRE(![String](Type-String.png "String") Pattern, ![Number](Type-Number.png "Number") Start)

Returns the 1st occurrence of the string S starting at N and going to the end of the string using REGEX functions, returns 0 if not found (10 ops)

### ![Number](Type-Number.png "Number") = ![String](Type-String.png "String"):find(![String](Type-String.png "String") Needle)

Returns the 1st occurrence of the string S, returns 0 if not found (6 ops)

### ![Number](Type-Number.png "Number") = ![String](Type-String.png "String"):find(![String](Type-String.png "String") Needle, ![Number](Type-Number.png "Number") Start)

Returns the 1st occurrence of the string S starting at N and going to the end of the string, returns 0 if not found (6 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):replace(![String](Type-String.png "String") Needle, ![String](Type-String.png "String") New)

Finds and replaces every occurrence of the first argument with the second argument (8 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):replaceRE(![String](Type-String.png "String") Pattern, ![String](Type-String.png "String") New)

Finds and replaces every occurrence of the first argument using REGEX with the second argument (12 ops)

### ![Array](Type-Array.png "Array") = ![String](Type-String.png "String"):explode(![String](Type-String.png "String") Delim)

Splits the string into an array, along the boundaries formed by the string S. See also String.Explode (2 ops)

### ![Array](Type-Array.png "Array") = ![String](Type-String.png "String"):explodeRE(![String](Type-String.png "String") Delim)

Splits the string into an array, along the boundaries formed by the string pattern S. See also String.Explode (5 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):reverse()

Returns a reversed version of S (6 ops)

### ![String](Type-String.png "String") = format(![String](Type-String.png "String") Fmt, ...)

Formats a values exactly like Lua's [http://www.lua.org/manual/5.1/manual.html#pdf-string.format string.format]. Any number and type of parameter can be passed through the "...". Prints errors to the chat area (3 ops)

### ![Array](Type-Array.png "Array") = ![String](Type-String.png "String"):match(![String](Type-String.png "String") Pattern)

runs string.match(S, S2) and returns the sub-captures as an array (10 ops)

### ![Array](Type-Array.png "Array") = ![String](Type-String.png "String"):match(![String](Type-String.png "String") Pattern, ![Number](Type-Number.png "Number") Position)

runs string.match(S, S2, N) and returns the sub-captures as an array (10 ops)

### ![Table](Type-Table.png "Table") = ![String](Type-String.png "String"):gmatch(![String](Type-String.png "String") Pattern)

runs string.gmatch(S, S2) and returns the captures in arrays in a table (12 ops)

### ![Table](Type-Table.png "Table") = ![String](Type-String.png "String"):gmatch(![String](Type-String.png "String") Pattern, ![Number](Type-Number.png "Number") Position)

runs string.gmatch(S, S2, N) and returns the captures in arrays in a table (12 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):matchFirst(![String](Type-String.png "String") Pattern)

runs string.match(S, S2) and returns the first match or an empty string if the match failed (10 ops)

### ![String](Type-String.png "String") = ![String](Type-String.png "String"):matchFirst(![String](Type-String.png "String") Pattern, ![Number](Type-Number.png "Number") Position)

runs string.match(S, S2, N) and returns the first match or an empty string if the match failed (10 ops)

### ![String](Type-String.png "String") = toUnicodeChar(...)

Returns the UTF-8 string from the given Unicode code-points (3 ops)

### ![String](Type-String.png "String") = toUnicodeChar(![Array](Type-Array.png "Array") Args)

Returns the UTF-8 string from the given Unicode code-points (3 ops)

### ![Array](Type-Array.png "Array") = ![String](Type-String.png "String"):toUnicodeByte(![Number](Type-Number.png "Number") Startpos, ![Number](Type-Number.png "Number") Endpos)

Returns the Unicode code-points from the given UTF-8 string (3 ops)

### ![Number](Type-Number.png "Number") = ![String](Type-String.png "String"):unicodeLength(![Number](Type-Number.png "Number") Startpos, ![Number](Type-Number.png "Number") Endpos)

Returns the length of the given UTF-8 string (3 ops)

### ![String](Type-String.png "String") = compress(![String](Type-String.png "String") Plaintext)

Compresses the input string using LZMA compression. See decompress(string) (10 ops)

### ![String](Type-String.png "String") = decompress(![String](Type-String.png "String") Compressed)

Decompresses an LZMA-compressed string. See compress(string) (10 ops)

### ![String](Type-String.png "String") = hashCRC(![String](Type-String.png "String") Text)

Returns a the CRC checksum of the input string. This is not a secure hash function (5 ops)

### ![String](Type-String.png "String") = hashMD5(![String](Type-String.png "String") Text)

Returns the MD5 hash of the input string. This is not a secure hash function; see hashSHA256 (5 ops)

### ![String](Type-String.png "String") = hashSHA1(![String](Type-String.png "String") Text)

Returns the SHA1 hash of the input string. This is not a secure hash function; see hashSHA256 (5 ops)

### ![String](Type-String.png "String") = hashSHA256(![String](Type-String.png "String") Text)

Returns the SHA256 hash of the input string (5 ops)
