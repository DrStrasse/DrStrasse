[Jump to table of contents](#default-extensions)

# Files

### ![Number](Type-Number.png "Number") = fileLoad(![String](Type-String.png "String") Filename)

Loads specified file to the server (100 ops)

### ![Number](Type-Number.png "Number") = fileCanLoad()

Returns 1 if the file can be loaded (3 ops)

### ![Number](Type-Number.png "Number") = fileLoadQueued()

Returns the number of files in the load queue (3 ops)

### ![Number](Type-Number.png "Number") = fileLoaded()

DEPRECATED. Use 'event fileLoaded(FilePath:string, Data:string)' instead! Returns whether or not the file has been loaded onto the server (5 ops)

### ![Number](Type-Number.png "Number") = fileLoading()

DEPRECATED. Use 'event fileLoaded(FilePath:string, Data:string)' instead! Returns whether a file is currently uploading (5 ops)

### ![Number](Type-Number.png "Number") = fileStatus()

DEPRECATED. Use 'event fileLoaded(FilePath:string, Data:string)' and 'event fileErrored(FilePath:string, Status:number)' instead! Returns the status of the upload in progress. Returns one of _FILE_UNKNOWN, _FILE_OK, _FILE_TIMEOUT, _FILE_404 or _FILE_TRANSFER_ERROR (5 ops)

### ![String](Type-String.png "String") = fileName()

DEPRECATED. Use 'event fileLoaded(FilePath:string, Data:string)' instead! Returns the name of the last uploaded file, or an empty string if there is no currently uploaded file (5 ops)

### ![String](Type-String.png "String") = fileRead()

DEPRECATED. Use 'event fileLoaded(FilePath:string, Data:string)' instead! Returns the contents of the last uploaded file, or an empty string if there is no currently uploaded file (10 ops)

### ![Number](Type-Number.png "Number") = fileMaxSize()

Returns the maximum file size that can be uploaded or downloaded. Default is 300 KiB (3 ops)

### ![Number](Type-Number.png "Number") = fileCanWrite()

Returns 1 if the file can be written (3 ops)

### ![Number](Type-Number.png "Number") = fileWriteQueued()

Returns the number of files in the write queue (3 ops)

### ![Number](Type-Number.png "Number") = fileWrite(![String](Type-String.png "String") Filename, ![String](Type-String.png "String") Data)

Writes string data to the file overwriting it (100 ops)

### ![Number](Type-Number.png "Number") = fileAppend(![String](Type-String.png "String") Filename, ![String](Type-String.png "String") Data)

Adds string data to the end of the file (100 ops)

### ![Number](Type-Number.png "Number") = fileList(![String](Type-String.png "String") Dir)

Loads a list of file names in the directory (100 ops)

### ![Number](Type-Number.png "Number") = fileCanList()

Returns 1 if the file list can be uploaded to the server (3 ops)

### ![Number](Type-Number.png "Number") = fileListQueued()

Returns the number of lists in the list queue (3 ops)

### ![Number](Type-Number.png "Number") = fileLoadedList()

DEPRECATED. Use 'event fileList(Path:string, Contents:array)' instead! If the list has been loaded and it is called, it will return 1. Any time after that until a new list is loaded it will return 0 (5 ops)

### ![Number](Type-Number.png "Number") = fileLoadingList()

DEPRECATED. Use 'event fileList(Path:string, Contents:array)' instead! Returns whether a list is currently uploading (5 ops)

### ![Array](Type-Array.png "Array") = fileReadList()

Returns the contents of the last uploaded list (5 ops)

### runOnFile(![Number](Type-Number.png "Number") Active)

DEPRECATED. Use 'event fileLoaded(FilePath:string, Data:string)' instead! Specifies whether the E2 will run when a file finishes uploading (5 ops)

### ![Number](Type-Number.png "Number") = fileClk()

DEPRECATED. Use 'event fileLoaded(FilePath:string, Data:string)' instead! Returns whether the execution was run because a file finished uploading (5 ops)

### ![Number](Type-Number.png "Number") = fileClk(![String](Type-String.png "String") Filename)

DEPRECATED. Use 'event fileLoaded(FilePath:string, Data:string)' instead! Returns whether the execution was run because a file finished uploading and was that file of a specific file name (5 ops)

### runOnList(![Number](Type-Number.png "Number") Active)

DEPRECATED. Use 'event fileList(Path:string, Contents:array)' instead! Specifies whether the E2 will run when a file list finishes uploading (5 ops)

### ![Number](Type-Number.png "Number") = fileListClk()

DEPRECATED. Use 'event fileList(Path:string, Contents:array)' instead! Returns whether the execution was run because a list was uploaded to the server (5 ops)

### ![Number](Type-Number.png "Number") = fileListClk(![String](Type-String.png "String") Dir)

DEPRECATED. Use 'event fileList(Path:string, Contents:array)' instead! Returns whether the execution was run because a list with specified name was uploaded to the server (5 ops)
