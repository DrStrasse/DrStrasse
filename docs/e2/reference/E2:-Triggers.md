> [!WARNING] 
> *BEFORE YOU READ THIS!*  
> The trigger system is replaced with the `event` system for the most part.  
> You may view this page if you need to make use of `interval` and `timer`. Otherwise, we strongly advice you to see [the events page](https://github.com/wiremod/wire/wiki/Expression-2-Events) instead!

# Table of Contents

   * [Intro](#intro) (Fundamentals, first(), Input, Timers)
   * [More Examples](#more-examples)
      * [Chat](#chat)
      * [Dupe](#dupe)
      * [Tick](#tick)
      * [File](#file)
      * [Key](#key)
      * [Others](#others)

# Intro
E2 works on a trigger based system and once the E2 gets triggered by *anything*, the **whole code** will be executed, at once, "instantaneous".

In short, this means you **cannot "delay" code or make the E2 "pause" or "sleep"** and attempting to "wait" for events with a `while` loop will cause the E2 to **crash**. Instead you will have to save whatever data you need using `@persist` and schedule a **timer** to continue later.

Another effect is that *all* code will get executed, so even code you might not want to.  
For this reason it is a **good idea to have no code outside a `if(<trigger check>)`**.  
I like using `if(<trigger1>){<code1>} elseif(<trigger2>){<code2>} ...` to make sure only one block of code runs, but this is by no means required.

Below is an example using 3 different trigger types:

* `first()`, triggered when spawning the E2
* Input (`~InputName`), by default any change in a wire input will execute the E2
* Timers (`clk("timer_name")`), which are scheduled manually with `timer(Name, Delay)`

```golo
@name TriggerExample
@inputs Start Delay
@output Done
@persist Counter # Keep this variable between executions
if( first() ) {
  print( "E2 was spawned!" )
}
elseif( ~Start ) {
  print( "Start input changed value!")
  if( Start ) {
	Counter = Delay
	stoptimer( "decrease_counter" ) # Stop any existing timers, to combat button-spam
	timer( "decrease_counter", 1000 ) # Schedule a execution in 1000ms (=1s)
  }
}
elseif( clk( "decrease_counter" ) ) {
  print( "Triggered by timer with name decrease_counter" )
  Counter--
  if( Counter > 0) {
	timer( "decrease_counter", 1000 ) # Schedule another execution
  }
  else { # Counter <= 0
	print("Time's up!")
	Done = 1
	timer( "reset_output", 500 ) # Schedule a different timer in 0.5s
  }
}
elseif( clk("reset_output") ) {
  print( "Triggered by timer with name reset_output" )
  Done = 0
}
```
# More Examples


There are many more trigger types, each corresponding to special events, so you do not need constantly running code to detect those. 

Here are the most commonly used ones:

## Chat
```golo
@name Chat
if( first() ) {
  runOnChat(1) # activate chat trigger
}
elseif( chatClk() ) { # just chatClk() returns 1 when someone wrote something in chat
  print( lastSpoke():name() + " wrote in chat: " + lastSaid())
}
```
Once activated with `runOnChat(1)`, the E2 will be activated any time someone writes something to chat.

The function `chatClk()` checks if the current execution was trigged by a chat message.

Using `chatClk( Player )` allows you to check if that certain Player sent that message.  
This is commonly used as `if( chatClk( owner() ) )`, to make the E2 only react to commands by the owner()

The functions `lastSpoke()` and `lastSaid()` allow you to get the sender and content of the message.

For more on how to implement chat commands see: [[E2: Chat Commands]]

## Dupe
```golo
@name Dupe
if( first() ) {
  print( "Spawned with Toolgun" )
}
elseif( duped() ) {
  print( "Spawned by duplicator" )
}
```
`duped()` is triggered whenever a E2 is not spawning with the E2 tool, but by any duplicator tool.
This is usually used as `if( first() | duped() )` to correctly initialize after a dupe or `if( duped() ) { reset() }` to completely reset and emulate a "fresh spawn"

Note: Advanced Duplicator (both 1 and 2) will additionally trigger for `dupefinished()` when it is done with spawning everything.

## Tick
```golo
@name Tick
@inputs On
@outputs Dice
if( ~On ) {
  runOnTick( On ) # If On Input changed, enable/disable the tick-trigger
}
elseif( tickClk() ) {
  Dice = randint( 1, 6 ) # Output a random number every tick
}
```
Like Chat, the Tick-trigger has to be enabled manually. It will execute the E2 once every gametick (Default: every 15ms, 66.6x per second).
You cannot interact with the world faster, so this is usually used to poll inputs, generate outputs or whenever you want something constantly running, such as physics interactions

See also [[E2: Detect events in the world]]

## File

Since E2 runs on the server, whenever you want it to read one of your files it has to be sent to the server first, which takes time. Once the file is uploaded completely the file trigger executes, assuming you activated runOnFile.

```golo
@name Persistent Highscore
@inputs Score
@outputs Highscore
if( first() | duped() ) {
  Highscore=-1 # mark as invalid
  timer("tryLoad", 0) # try loading the next tick
}
elseif( clk("tryLoad") )
  if( fileCanLoad() ) {
    fileLoad("highscore.txt") # Upload data/e2files/highscore.txt
    runOnFile(1)
  }
  else {
    timer("tryLoad", 500) # try again in 500ms
  }
}
elseif( fileClk("highscore.txt") ) { # File trigger
  runOnFile(0) # no longer needed, we got our result
  if( fileStatus()==_FILE_OK ) {
    Highscore = fileRead():toNumber() # Read number and output it
  }
  else {
    error("File load failed with error code: "+fileStatus())
  }
}
elseif( ~Score ) { # Input trigger
  if( Highscore!=-1 & Score>Highscore ){ # Highscore loaded already and the new score is higher
    Highscore = Score
    print("New Highscore: "+Highscore)
    if( fileCanWrite() ) {
      fileWrite("highscore.txt", Highscore:toString() ) # directly save new value to file
    }
    else {
      print("Could not save score!") # retrying later would be much better, similar to tryLoad above
    }
  }
}
```
You might have noticed that we use a timer to load the file. This is because some features in E2 (like accessing files or http, creating holograms or props and find functions) are throttled, so you might have to wait some time between calling them. If the check (here `fileCanRead()`) fails, we just try again and again (with a brief delay) until it works, as shown above with the `tryLoad` timer.  
Note that writing to file is done with just the single `fileWrite` function and needs no special trigger, since you do not have results you need to wait on.

**FileList** and **Http** triggers have pretty much the same structure.

## Key

`runOnKeys` lets you listen for key (and mouse) events from a specific player. Note that this triggers on *press* **and** *release* of the key, so you want to check if `keyClk(TargetEntity)` is 1 (press) or -1 (release).

You can use the following code (by Divran) as starting point to figure out the key/bind names you are interested in and then either use them in the `runOnKeys` filter array, and/or check the value of `keyClkPressed()` if you want to distinguish between different keys.

```golo
if (first()) {
    runOnKeys(owner(),1) #alternatively runOnKeys(owner(),1,array("w","a","s","d")) to filter
} elseif (keyClk()) {
    local Ply = keyClk() # player who pressed the key
    local Pressed = keyClk(Ply) # 1 = key was pressed, -1 = key was released
    local Key = keyClkPressed() # the key that was pressed

    # Alternately you can also get the pressed bind.
    # local PressedBind = keyClkPressedBind()

    if (Pressed == 1) {
        print("Player",Ply,"pressed key",Key)
    } elseif (Pressed == -1) {
        print("Player",Ply,"released key",Key)
    }
}
```

Note that not everyone may be using the same keyboard layout or control setup as you, so you may want to use binds instead of keys.  
They also work in the filter.

If you want to listen to all players, you can do `runOnKeys(players(), 1, OptionalFilterArray)` to enable it for all current players. If you want it to listen to players that join later, you want to use `runOnJoin` to enable it as soon as they join.

## Others
Apart from `first()`, `duped()`, Inputs, Timers, Chat and Tick there exist many other triggers that you may or may not run into. You can search the E2 Helper for "runOn" or "clk" to find most of them.

Here is a quick rundown of lesser used triggers:

* Last: allows you to do one last run when deleting the E2 
* FileList: Works similar to File, but gets a list of directory contents
* Http: Works similar to File, but downloads data from a given URL
* (Data)Signals: Used for wireless communication between E2s