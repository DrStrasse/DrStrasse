Table of Contents
=================

   * [Intro](#intro)
   * [Lookup Tables](#lookup-tables)
      * [SteamID Whitelist](#steamid-whitelist)
      * [Shortcuts](#shortcuts)
   * [Why changed doesn't do what you think it does](#why-changed-doesnt-do-what-you-think-it-does)
      * [Problem 1](#problem-1)
      * [Problem 2](#problem-2)
      * [Better Solutions](#better-solutions)
   * [Switch Case](#switch-case)
      * [Example](#example)
   * [Persist a single table](#persist-a-single-table)
      * [Basics](#basics)
      * [Changing Values on the fly](#changing-values-on-the-fly)
      * [Easy save and load](#easy-save-and-load)
      * [More](#more)
   * [Coming Soon™:](#coming-soon)

# Intro
On this page I will some you some cool tricks and techniques I learned over the years that can save you a lot of time, trouble and headaches.

# Lookup Tables
Lookup tables are a easy way to access a multitude of values without complicated if statements or looping over arrays.
Tables and arrays return the default "empty" value (0 for numbers) if there is no matching entry found.

The basics work like this:
```golo
# Create table once, using numbers as values
Table = table("someKey" = 1, "someOtherKey" = 42, "STEAM_0:0:12345"=1)
# Write to table
Table[Key, number] = Value
# Example usecases
if(Table:exists(Key)){ ... # Check if entry exists
if(Table[Key, number]){ ... # Check if entry is !=0 (and exists)
Value = Table[Key, number] ?: 1337 # Read value from table or return a default value if entry doesn't exist
```
Note that above examples use numbers, but you can make lookup tables for every value type, including other tables.

## SteamID Whitelist
The single most common usecase is using a lookup table as whitelist to control access. Note that we use SteamID instead of player name or entity id, because it cannot be spoofed and is unaffected by rejoins. If you wanted you could even load the table contents from a file to keep as persistent friendlist for all your E2s.

```golo
@persist Whitelist:table  # persist make variables keep their value between multiple executions, ie multiple chatClk runs
if(first()){
   # add owner and two hardcoded ids
  Whitelist = table( owner():steamID()=1, "STEAM_0:0:11111"=1, "STEAM_0:0:22222"=1)
}
...
  # Example checking of whitelist
  if(Whitelist:exists(Target:steamID())){
    print("Target on Whitelist")
  }
...
  # Example of adding players by name (removing works similar, just set it to 0 if its on the list)
  local Target = findPlayerByName( Input )
  if(Whitelist:exists(Target:steamID())){
    print("Already on whitelist")
  }
  else{
    Whitelist[Target:steamID(), number] = 1
    print("Added "+Target:name())
  }
```
(To see how to make a chat command that targets players, check out [[this section|E2:-Chat-Commands#targeting-player-by-names]].)

While we just use a value of 1 here, you can easily expand this to store some kind of access level, people with 1 may only use a single door, while people with 2 have access to all doors, and you could have admins with a value of 3 able to add or remove other users, or whatever custom system you can think of.  
The same basic principle of using a table with SteamID can also be used to have a database, storing whatever data you can imagine for individual players, but this is left as an exercise to the reader.

## Shortcuts
In the same way that you can store numbers linked to SteamIDs for a whitelist, you can also store anything else linked to strings. The following example shows how you can use lookup tables to enable shortcuts or aliases for a train track spawner, so you don't have to use the full model name all the time.

```golo
@persist Models:table
if(first()){
  Models = table(
    "short_straight" = "models/sprops/trans/train/track_s01.mdl",
    "straight" = "models/sprops/trans/train/track_s03.mdl",
    "long_straight" = "models/sprops/trans/train/track_s06.mdl",
    "tight_turn" = "models/sprops/trans/train/track_t90_01.mdl",
    "wide_turn" = "models/sprops/trans/train/track_t90_01.mdl"
  )
  ...
} 
...
  local Input = ... # Get input, maybe from chat command
  # Check lookup table if there is a entry for the input. If the result is empty (no entry), just use the input directly
  local FinalModel = Models[Input, string] ?: Input
  propSpawn(FinalModel, ... , 1)
```
Doing it this way is much easier to expand than doing the same with ifs (equivalent code below):
```golo
local FinalModel = ""
if( Input == "short_straight" ){ FinalModel = "models/sprops/trans/train/track_s01.mdl" }
elseif( Input == "straight" ){ FinalModel = "models/sprops/trans/train/track_s03.mdl" }
...
elseif( Input == "wide_turn" ){ FinalModel = "models/sprops/trans/train/track_t90_01.mdl" }
else{ FinalModel = Input}
```

# Why changed doesn't do what you think it does

`changed()` is one the hardest function in E2 to understand, even though it might seem straightforward.

Most people will probably think it tells you if the value changed since the last execution of the E2. And while that *appears* correct in most cases, it is not quite correct.

## Problem 1

```golo
@input Button
if (Button) {
  print("Hello")
  if (changed(Button)) {
    print("World")
  }
}
timer("run again", 1000)
```
You might think this prints "Hello" and "World" every time the button is pressed (since Button *changed* from 0 to 1) and "Hello" while it is held down.   
Instead it prints "World" only the very first time.

This is because it doesn't compare against the last tick/interval/whatever, but to the last *call*. And since `changed` only gets called when the Button is 1 (due to the outer `if`), `changed` only "sees" a static value of 1. The first time works, because `changed` start off with an internal value of 0.

Notes:  
The same issue happens as well with `if( Button & changed(Button) )`, because E2 optimizes logic operations so it doesn't even check the later parts (and therefore doesn't call `changed`) when Button is 0, because `0 & <whatever>` will *always* be 0.  
You could use `if( changed(Button) & Button )`, but usually you want `if(~Button & Button)` in that case (see the note about inputs [below](#better-solutions)).

## Problem 2

```golo
@input Button
for(I=1,3) {
  if(changed(Button)) {
    print(I)
  }
}
timer("run again", 1000)
```
What do you think it will output whenever the button is pressed or released? 1, 2 and 3? Nope. Just 1.

This is because internally it keeps track of the last call value based on the **position of the call in the code**. So all three iterations of the loop check the same internal value. It sees the new value on the first iteration (and prints 1), but since the first iteration already updated the internal value, the second and third iteration see no change.

In this example you could just reorder the code (`if(...){for(...){...}}`), but you might want to different values for the iterations...

Note:  
This behavior not only applies to loops but also **custom functions**, even when when called from multiple places.

## Better solutions
* **Inputs:** In most cases you want to use the trigger operator (ie `~Button`), which checks if the E2 was triggered *because* the input changed. See [[E2: Triggers]] for more infos on E2s trigger system.
* **Variable updates:** When you use `changed` to check if **you** modified a value in some other part of the code (ie. to update some display), you could be using custom function to do your update right then and there, or (if you expect multiple values could update and you want to avoid multiple updates) use an additional variable as shared flag (ie. set `ShouldUpdate = 1` and check that instead).
* **Arrays/Tables**: Sorry, but there is no good way around doing what `changed` does yourself (but you _can_ account for the index, `changed` can not) - Keep a copy of the last values and compare against that, element by element (ie `for(I=1,Length){if(Current[I,number]!=Last[I,number]){print(I+" changed"),Last[I,number]=Current[I,number]}}`).

# Switch Case

E2 supports [Switch Statements](https://en.wikipedia.org/wiki/Switch_statement), which offer a more elegant solution to long if-elseif chains when you want to do different things based on the value of a single variable.

However, if you are just trying to assign different values to different inputs but the code is otherwise the same, a [lookup table](#lookup-tables) is an even better solution.

## Example

```golo
switch(Command){  # The variable to check
  case "print",   # do this when Command == "print"
    print("Hello")
    break         # end of this block
  case "reset",   # multiple cases are allowed
  case "restart", # do this when Command == "reset" or Command == "restart"
    reset()
    break
  case "save_and_exit",
    save_something() # notice the missing "break" here
  case "exit",       # if there is no break, it continues on with the next block
    exit()           # so exit() is ran in both cases, but save only in the top one
    break
  default,           # ran when no case matches, this is optional
    error("command not found")
}
```
On first glance it might look intimidating or complicated, but especially when you can put the multiple cases(reset/restart) or fallthrough (save_and_exit) to good use it can be simpler than the equivalent if-elseif chain:

```golo
if(Command == "print"){
  print("Hello")
}
elseif(Command == "reset" | Command == "restart"){
  reset()
}
elseif(Command == "save_and_exit" | Command == "exit"){
  if(Command == "save_and_exit"){
    save_something()
  }
  exit()
}
else{
  error("Command not found")
}
```
You can find another example in the [Chat Commands](https://github.com/adosikas/wire/wiki/E2:-Chat-Commands#switch-case) page.

# Persist a single table

When working on a larger project you probably have seen it: Your `@persist` line is growing longer and longer, and maybe you already started a second or third row

Here is an example using a single table to store multiple settings and timing info for a customizable floating holo:

## Basics
```golo
@name HoloBubble
@inputs Spawn
@persist P:table
if(first()){
  # default settings
  P=table(
    "speed"=2,
    "scale"=1,
    "alpha"=127,
    "material"="models/debug/debugwhite",
    "lifetime"=50 )
  runOnChat(1) # We'll need this later
}
elseif(~Spawn & Spawn){ # Button pressed
  holoCreate(1, entity():pos(), vec(P["scale",number]), ang())
  holoAlpha(1, P["alpha",number])
  holoMaterial(1, P["material",string])
  P["holo age",number]=0 # Just create new entries on the fly
  stoptimer("move") # stop any old timers
  timer("move", 100)
}
elseif(clk("move")){
  if(P["holo age",number]<P["lifetime",number]){
    holoPos(1, holoEntity(1):pos()+vec(0,0,P["speed",number]))
    timer("move", 100)
  }
  else{
    holoDelete(1) # delete holo after its too old
  }
}
```
## Changing Values on the fly
But being able to easily create new entries on the fly isn't the only advantage: Since it is a table you can also dynamically access the values, for example to change values on the fly, or quickly check the state for debugging:
```golo
elseif(chatClk(owner())){
  local LS=owner():lastSaid():explode(" ")
  if(LS[1,string]=="!set"){
    hideChat(1)
    local Key = LS[2, string]
    local Value = LS[3, string]
    local Type = P:typeids()[Key,string] # get type of value
    switch(Type){
      case "n",
        P[Key,number]=Value:toNumber()
        print("Set number '"+Key+"' to "+P[Key,number])
        break
      case "s",
        P[Key,string]=Value
        print("Set string '"+Key+"' to "+P[Key,string])
        break
      case "",
        print("Key '"+Key+"' not found!")
        break
      default,
        print("Changing type '"+Type+"' not implemented!")
    }
  }
  elseif(LS[1,string]=="!debug"){
    printTable(P)
  }
  [...]
```
## Easy save and load
But wait! Thats not all! You can also easily save and restore the settings:
```golo
  [...]
  elseif(LS[1,string]=="!save"){
    local Output = "Bubblesettings:\n"+vonEncode(P) # Encode the table as string and add a header
    fileWrite(Output, "bubblesettings_"+LS[2,string]+".txt") # save with given name
  }
  elseif(LS[1,string]=="!load"){
    fileLoad("bubblesettings_"+LS[2,string]+".txt")  # load with given name
    runOnFile(1)
  }
}
elseif(fileClk()){
  local Content = fileRead()
  if(Content:left(16)=="Bubblesettings:\n"){ # Check header of file
    P = vonDecodeTable(Content:sub(17)) # just overwrite everthing at once
  }
  else{
    print("File is not a valid save")
  }
  runOnFile(0)
}
```
## More
Apart from that you can also do other stuff with the table, like [sharing it with other E2s](#shared-tables), wires or even transmiting it over the internet to your server (or load it from there) or use `P:merge(Defaults)` to quickly overwrite a certain set of values.

You can also use multiple persisted tables for different uses, maybe you only want to save certain settings, but not other info which might be useless when loaded later (like the holo age from above), or you are making a game and only want to share certain information with other E2s, and keeps others private.
Of course you can also nest tables, this allows for easy grouping: `P["settings",table]["color",vector]`, but when doing that you **have** to initialize the sub-table, for example: `if(first()){ P=table(...), P["subtable",table]=table(), ...`

Just keep in mind that you have to keep track of the entries yourself, as you will get no errors when you make typos, and a non-existant entry will just give you 0, an empty string, vec(0,0,0), etc depending on the type.

# Coming Soon™:

* shared tables
    * custom security
    * instant syncronisation
    * fully transparent
* holo/egp id handling
    * named ids
    * table instead of copy/pasting holoCreate
* egp list/grid interfaces
* holo-only touchscreens