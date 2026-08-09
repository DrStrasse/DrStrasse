> [!WARNING]
> This article is in need of cleanup to remove outdated information. See [Expression 2 Events: Chat Commands](/wiremod/wire/wiki/Expression-2-Events#-chat-commands) for a simple guide and [E2 Guide: Lambdas: Chat Command Look-Up Table](/wiremod/wire/wiki/E2-Guide:-Lambdas#chat-command-look-up-table) for a step-by-step guide using lambdas.

Table of Contents
=================

   * [Basics](#basics)
   * [Arguments](#arguments)
      * [Targeting player by names](#targeting-player-by-names)
      * [Text with spaces](#text-with-spaces)
   * [Multiple commands](#multiple-commands)
      * [Switch-Case](#switch-case)

# Basics

E2 comes with a trigger for chat events, you can find more about how E2 triggers work in general here: [[E2:-Triggers]]

To get a E2 to react to basic chat commands is quite simple:

```golo
@name ChatTrigger
# Will output a short pulse whenever someone types "!trigger" into chat
@outputs Trigger
if( first() ) {
  runOnChat(1)                   # enable chat trigger (during first run)
}
elseif( chatClk() ) {            # E2 triggered by any chat message
  local Message = lastSaid()     # get message
  if( Message == "!trigger" ) {  # matches command?
    Trigger = 1
    stoptimer( "reset" )         # abort currently running timer
    timer( "reset", 150 )        # shedule run in 150ms
  }
}
elseif( clk( "reset" ) ) {
  Trigger = 0
}
```
Now if the E2 should only react to a certain player (like you, `owner()`), all you need to is use `chatClk( owner() )` instead of `chatClk()`.

# Arguments
Most of the time you want to send some data along with the command such as a value. The easiest way to handle that is to split the incoming message at every space.
```golo
@name ChatAddtion
# Will add two numbers together when the owner types "!add [Number1] [Number2]"
if( first() ) {
  runOnChat(1)                                  # enable chat trigger (during first run)
}
elseif( chatClk( owner() ) ) {                  # E2 triggered by a chat message of the owner
  local Message = lastSaid()                    # get message
  local Words = Message:explode(" ")            # split message at spaces (into words)
  if( Words[1, string] == "!add" ) {            # first word matches command?
    hideChat( 1 )                               # prevent command from showing up in chat
    local Number1 = Words[2, string]:toNumber() # get second word and convert it to number
    local Number2 = Words[3, string]:toNumber() # get third word and convert it to number
    local Result = Number1 + Number2
    print( "Result: " + Result )
  }
}
```
Here `Words` is an array containing the split message in order, ie: `array( 1 = "!add", 2 = "37", 3 = "73" )`. Note that all of those are strings, so to get the numeric value of the summands we first have to use `toNumber()`  
`hideChat` allows you to prevent your own messages (commands) from appearing in the chat. Other E2s and many more things can still detect it, as it only prevents the message from being displayed.

## Targeting player by names
```golo
@name SteamID
# Will print the steamID of someone when the owner types "!getid [name]"
if( first() ) {
  runOnChat(1)                                    # enable chat trigger (during first run)
}
elseif( chatClk( owner() ) ) {                    # E2 triggered by a chat message of the owner
  local Message = lastSaid()                      # get message
  local Words = Message:explode(" ")              # split message at spaces (into words)
  if( Words[1, string] == "!getid" ) {            # first word matches command?
    local SearchName = Words[2, string]           # get second word
    local Player = findPlayerByName( SearchName ) # try to find a player that matches that
    if( !Player:isPlayer() ) {
      print( "Could not find a playername matching '" + SearchName + "'." )
    }
    else {
      print( "Player '" + Player:name() +"' has steamid: " + Player:steamID() )
    }
  }
}
```
Note that this will find a player whose name contains the second word, ie `!getid Red` might give you the ID's of 'Red Five', 'RedditOctober' or even 'BigRed'.  
It also will have trouble with names that include spaces (see next section for a possible way to fix), duplicate names or names with special characters.

## Text with spaces
While splitting the Message at spaces is easy and makes sense in most cases, sometimes a text with spaces is needed.  
For this you can just recombine the words again:
```golo
@name ReversePrint
# Will print the reverse of the input "!reverse [text with spaces]"
if( first() ) {
  runOnChat(1)                          # enable chat trigger (during first run)
}
elseif( chatClk( owner() ) ) {          # E2 triggered by a chat message of the owner
  local Message = lastSaid()            # get message
  local Words = Message:explode(" ")    # split message at spaces (into words)
  if( Words[1,string] == "!reverse" ) { # first word matches command?
    local Text = Words:concat(" ", 2)   # combine the words again, starting at the 2nd Word
    print( Text:reverse() )             # output it backwards
  }
}
```

# Multiple commands
To run multiple commands you don't need copy the whole code over, just adding another if is enough:

```golo
@name ChatOpenClose
# Will change the output whenever the owner types !open or !close
@outputs Open
if( first() ) {
  runOnChat(1)                    # enable chat trigger (during first run)
}
elseif( chatClk() ) {             # E2 triggered by any chat message
  local Message = lastSaid()      # get message
  if( Message == "!open" ) {      # matches command?
    Open = 1
  }
  elseif( Message == "!close" ) { # matches other command?
    Open = 0
  }
}
```
Ofcourse this will work with the word-based approach from above as well.

## Switch-Case
While simply adding more if's works, I prefer [[Switch-Case|E2:-Tips-and-Tricks#Switch-Case]] statements.

In this example I will also use a prefix (`!math`), I recommended this if you add many commands, to avoid interfering with server commands or other E2s
```golo
@name ChatMath
# Does basic math operations, !math [operation] [number1] [number2]
@outputs Output
if( first() ) {
  runOnChat( 1 )
}
elseif( chatClk() & lastSaid():left(5) == "!math" ) { # chat trigger and left 5 chars are the prefix
  local Message = lastSaid()
  local Words = Message:explode(" ")
  local Num1 = Words[3, string]:toNumber()        # since all commands use the same structure, we can get the numbers already
  local Num2 = Words[4, string]:toNumber()

  switch( Words[2, string] ) {                    # switch depending on operation
    case "add",                                   # '!math add ...' or '!math plus ...'
    case "plus",
      Output = Num1 + Num2
      break                                       # end of this case
    case "sub",
    case "minus",
      Output = Num1 - Num2
      break
    case "mul",
      Output = Num1 * Num2
      break
    case "div",
      Output = Num1 / Num2
      break
    default,                                      # incase no case exists for the input
      print( "Operation '" + Words[2, string] + "' not implemented")
      Output = 0
      break
  }
}