[Jump to table of contents](#default-extensions)

# Chat

### runOnChat(![Number](Type-Number.png "Number") Activate)

DEPRECATED. Use 'event chat(Player:entity, Message:string, Team:number)' instead! If set to 0, the chip will no longer run on chat events, otherwise it makes this chip execute when someone chats. Only needs to be called once, not in every execution (3 ops)

### ![Number](Type-Number.png "Number") = chatClk()

DEPRECATED. Use 'event chat(Player:entity, Message:string, Team:number)' instead! Returns 1 if the chip is being executed because of a chat event. Returns 0 otherwise (3 ops)

### ![Number](Type-Number.png "Number") = chatClk(![Entity](Type-Entity.png "Entity") Ply)

DEPRECATED. Use 'event chat(Player:entity, Message:string, Team:number)' instead! Returns 1 if the chip is being executed because of a chat event by player E. Returns 0 otherwise (3 ops)

### hideChat(![Number](Type-Number.png "Number") Hide)

Hides the chat messages written by E2 owner (3 ops)

### modifyChat(![String](Type-String.png "String") New)

Changes the chat message, if the chat message was written by the E2 owner (3 ops)

### ![Entity](Type-Entity.png "Entity") = lastSpoke()

DEPRECATED. Use 'event chat(Player:entity, Message:string, Team:number)' instead! Returns the last player to speak (3 ops)

### ![String](Type-String.png "String") = lastSaid()

DEPRECATED. Use 'event chat(Player:entity, Message:string, Team:number)' instead! Returns the last message in the chat log (3 ops)

### ![Number](Type-Number.png "Number") = lastSaidWhen()

Returns the time the last message was sent (3 ops)

### ![Number](Type-Number.png "Number") = lastSaidTeam()

DEPRECATED. Use 'event chat(Player:entity, Message:string, Team:number)' instead! Returns 1 if the last message was sent in the team chat, 0 otherwise (3 ops)

### ![String](Type-String.png "String") = ![Entity](Type-Entity.png "Entity"):lastSaid()

DEPRECATED. Use 'event chat(Player:entity, Message:string, Team:number)' instead! Returns what the player E last said (3 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):lastSaidWhen()

Returns when the given player last said something (3 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):lastSaidTeam()

DEPRECATED. Use 'event chat(Player:entity, Message:string, Team:number)' instead! Returns 1 if the last message was sent in the team chat, 0 otherwise (3 ops)
