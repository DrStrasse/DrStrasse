[Jump to table of contents](#default-extensions)

# Debug

### ![Number](Type-Number.png "Number") = playerCanPrint()

Returns whether or not the next print-message will be printed or omitted by antispam (2 ops)

### print(...)

Prints all arguments to the chat area, seperated by a tab. Automatically does toString for you (Can print arrays but not tables). Works just like lua's print (40 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):printDriver(![String](Type-String.png "String") Text)

Posts a string to the chat of Es driver. Returns 1 if the text was printed, 0 if not (30 ops)

### hint(![String](Type-String.png "String") Text, ![Number](Type-Number.png "Number") Duration)

Displays a hint popup with message S for N seconds (N being clamped between 0.7 and 7) (30 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):hintDriver(![String](Type-String.png "String") Text, ![Number](Type-Number.png "Number") Duration)

Displays a hint popup to the driver of vehicle E, with message S for N seconds (N being clamped between 0.7 and 7). Same return value as printDriver (30 ops)

### print(![Number](Type-Number.png "Number") Print_type, ![String](Type-String.png "String") Text)

Same as print(S), but can make the text show up in different places. N can be one of the following: _HUD_PRINTCENTER, _HUD_PRINTCONSOLE, _HUD_PRINTNOTIFY, _HUD_PRINTTALK (30 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):printDriver(![Number](Type-Number.png "Number") Print_type, ![String](Type-String.png "String") Text)

Same as EE:printDriver(S), but can make the text show up in different places. N can be one of the following: _HUD_PRINTCENTER, _HUD_PRINTCONSOLE, _HUD_PRINTNOTIFY, _HUD_PRINTTALK (30 ops)

### printTable(![Array](Type-Array.png "Array") Arr)

Prints an array like the lua function PrintTable does, except to the chat area (150 ops)

### printColor(...)

Works like chat.AddText(...). Parameters can be any amount and combination of numbers, strings, player entities, color vectors (both 3D and 4D) (150 ops)

### printColor(![Array](Type-Array.png "Array") Arr)

Like printColor(...), except taking an array containing all the parameters (150 ops)

### printColorC(...)

Works like MsgC. Parameters can be any amount and combination of numbers, strings, player entities, color vectors (both 3D and 4D) (150 ops)

### printColorC(![Array](Type-Array.png "Array") Arr)

Like printColorC(...), except taking an array containing all the parameters (150 ops)

### ![Entity](Type-Entity.png "Entity"):printColorDriver(...)

Like printColor but prints to the driver of a specified vehicle (150 ops)

### ![Entity](Type-Entity.png "Entity"):printColorDriver(![Array](Type-Array.png "Array") Arr)

Like printColorDriver but takes an array containing all the parameters (150 ops)

### setClipboardText(![String](Type-String.png "String") Text)

Adds the given string to the chip owners clipboard (100 ops)

### printCaption(![String](Type-String.png "String") Text, ![Number](Type-Number.png "Number") Duration, ![Number](Type-Number.png "Number") Fromplayer)

Emits a closed caption with the provided text and duration in seconds. The last argument is used to control the playerclr code (100 ops)

### printCaption(![String](Type-String.png "String") Text, ![Number](Type-Number.png "Number") Duration)

Emits a closed caption with the provided text and duration in seconds (100 ops)
