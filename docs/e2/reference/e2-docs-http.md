[Jump to table of contents](#default-extensions)

# Http

### httpRequest(![String](Type-String.png "String") Url)

Starts a new request (20 ops)

### ![Number](Type-Number.png "Number") = httpCanRequest()

Returns whether you can make a new request (delay has been met or previous request timed out) (5 ops)

### ![Number](Type-Number.png "Number") = httpClk()

DEPRECATED. Use 'event httpLoaded(Body:string, Size:number, Url:string)' and 'event httpErrored(Error:string, Url:string)' instead! Returns whether the execution was run because of a completed request (5 ops)

### ![String](Type-String.png "String") = httpData()

Returns the data received from the last request (5 ops)

### ![Number](Type-Number.png "Number") = httpSuccess()

Returns whether the previous request was successful (5 ops)

### ![String](Type-String.png "String") = httpRequestUrl()

Returns the URL of the last request (5 ops)

### ![String](Type-String.png "String") = httpUrlEncode(![String](Type-String.png "String") Data)

Returns formatted string to be placed in the URL (5 ops)

### ![String](Type-String.png "String") = httpUrlDecode(![String](Type-String.png "String") Data)

Returns decoded URL data (5 ops)

### runOnHTTP(![Number](Type-Number.png "Number") Rohttp)

DEPRECATED. Use 'event httpLoaded(Body:string, Size:number, Url:string)' and 'event httpErrored(Error:string, Url:string)' instead! Sets whether to run the expression when a request finishes (5 ops)
