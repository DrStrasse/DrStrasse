Expression 2 has `event`s that allow you to manage what parts of your code run when certain things happen, like a player typing in chat and when a player leaves the server.  
They're analogous to gmod's [`hook`](https://wiki.facepunch.com/gmod/hook) system if you are familiar Garry's Mod Lua.

## ❔ Why?
If you're here because of your code giving you warnings about certain `runOn*` functions being deprecated, this is for you.  

The [clk (trigger)](https://github.com/wiremod/wire/wiki/E2:-Triggers) system is the old way of handling "events" with `runOn*` and `*clk()` functions. It's being replaced due to being one of the most confusing and suboptimal things about the language.

Events are closer to what real world programming languages do, are more efficient, and simpler to understand.

## 🔣 Syntax
The syntax is pretty simple. They are similar to functions in how you declare them, but missing the return value type, and using `event` instead of `function`. *Note, however, that events are not functions. They are a compile time construct. You can't redeclare them or stop them, at least for now. Check a variable inside the event if you do not want code inside of it to run anymore.*

```golo
event chat(Ply:entity, Said:string, Team:number) {
    print(Ply, " just said ", Said)
}

Owner = owner()
event keyPressed(Ply:entity, Key:string, Down:number, Bind:string) {
    if (Ply == Owner & !Down) {
        print("Owner released key " + Key)
    }
}
```

Additionally, if you just begin to type `event ` and the name of the event, the editor will autocomplete the whole declaration for you!

## 📚 How do they work?
All events you write in the code are registered at compile time *once*. So you should nest them inside any `if` statement.  
Once they are registered, every time the event fires, **only the code inside of the event will run**. You can think of them as functions you give to lua.

## ⏲️ Timers
For simplicity and efficiency, timers work on a different system than events. See [[E2: Timers]].

# 📖 List of Events

<!--If editing this table, please consider keeping it alphabetized.-->
| Declaration                                                               | Description                                                                                                                                                                                                                                                                      |
|---------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `event chat(Player:entity, Message:string, Team:number)`                  | Runs when a `Player` sends a chat `Message`. `Team` is 1 if it's sent in team chat. Replaces `chatClk`.                                                                                                                                                                          |
| `event chipUsed(Player:entity)`                                           | Runs when the E2 chip is used by a `Player`. Replaces `useClk`.                                                                                                                                                                                                                  |
| `event egpHudConnect(Screen:wirelink, Player:entity, Connected:number)`   | Runs when a `Player` connects to an EGP HUD, `Screen`. `Connected` is 1 if the player is connecting and 0 if the player is disconnecting.                                                                                                                                        |
| `event entityCreated(Entity:entity)`                                      | Runs when an `Entity` is created.                                                                                                                                                                                                                                                |
| `event entityDamage(Victim:entity, Damage:damage)`                        | Runs when a `Victim` entity takes `Damage`.                                                                                                                                                                                                                                      |
| `event fileErrored(File:string, Error:number)`                            | Runs when a file fails to load. `File` is the path of the requested file, `Error` is the [error code enum](https://github.com/wiremod/wire/blob/2eb82805e7fc290e2cf03ff9fde2e587b6191610/lua/entities/gmod_wire_expression2/core/files.lua#L13). Replaces `fileClk`.             |
| `event fileList(Path:string, Contents:array)`                             | Runs when a file list operations succeeds. `Path` is the requested path, `Contents` is an array of file names and directories as strings. Replaces `fileListClk`.                                                                                                                |
| `event fileLoaded(File:string, Data:string)`                              | Runs when a file load succeeds. `File` is the path of the requested file, `Data` is the contents of the file. Replaces `fileClk`.                                                                                                                                                |
| `event fileWritten(File:string, Data:string)`                             | Runs when a file finishes sending to the client. `File` is the path of the file, `Data` is the written data.                                                                                                                                                                     |
| `event httpErrored(Error:string, Url:string)`                             | Runs when an HTTP request fails. `Error` is the error message and `Url` is the URL that was requested. Replaces `httpClk`.                                                                                                                                                       |
| `event httpLoaded(Body:string, Size:number, Url:string)`                  | Runs when an HTTP request succeeds. `Body` is the contents of the page, `Size` is the size of the page, and ` Url` is the URL that was requested. Replaces `httpClk`.                                                                                                            |
| `event input(InputName:string)`                                           | Runs when an input triggers the E2. `InputName` is the name of the input. Replaced `inputClk`.                                                                                                                                                                                   |
| `event keyPressed(Player:entity, Key:string, Down:number, Bind:string)`   | Runs when a `Player` presses or releases a `Key`. `Down` is 1 if the key is pressed and 0 if it is released. `Bind` corresponds to [this table](https://github.com/wiremod/wire/blob/2eb82805e7fc290e2cf03ff9fde2e587b6191610/lua/wire/wireshared.lua#L1066). Replaces `keyClk`. |
| `event playerChangedTeam(Player:entity, OldTeam:number, NewTeam:number)`  | Runs when a `Player` changes from `OldTeam` to `NewTeam`.                                                                                                                                                                                                                        |
| `event playerConnected(Player:entity)`                                    | Runs when a `Player` connects to the server. Replaces `playerConnectClk`.                                                                                                                                                                                                        |
| `event playerDeath(Victim:entity, Inflictor:entity, Attacker:entity)`     | Runs when a `Victim` player dies to the `Attacker` player. `Inflictor` is the weapon used. Replaces `deathClk`.                                                                                                                                                                  |
| `event playerDisconnected(Player:entity)`                                 | Runs when a `Player` disconnects from the server. Replaces `playerDisconnectClk`.                                                                                                                                                                                                |
| `event playerEnteredVehicle(Player:entity, Vehicle:entity)`               | Runs when a `Player` enters a `Vehicle`.                                                                                                                                                                                                                                         |
| `event playerLeftVehicle(Player:entity, Vehicle:entity)`                  | Runs when a `Player` leaves a `Vehicle`.                                                                                                                                                                                                                                         |
| `event playerMove(Player:entity, MoveData:movedata, Command:usercmd)`     | Runs when a `Player` moves with their mouse or keyboard.                                                                                                                                                                                                                         |
| `event playerSpawn(Player:entity)`                                        | Runs when a `Player` spawns, including respawns. Replaces `spawnClk`.                                                                                                                                                                                                            |
| `event playerUse(Player:entity, Entity:entity)`                           | Runs when a `Player` uses an `Entity`.                                                                                                                                                                                                                                           |
| `event remote(Sender:entity, Player:entity, Payload:table)`               | Event triggered by `broadcastRemoteEvent(t)` or `e:sendRemoteEvent(t)`, replacing datasignals and gtables                                                                                                                                                                        |
| `event removed(Resetting:number)`                                         | The last code ran before the chip is removed. `Resetting` is 1 if the E2 is resetting. Replaces `last`.                                                                                                                                                                          |
| `event tick()`                                                            | Runs on every game tick. Replaces `tickClk`.                                                                                                                                                                                                                                     |
| `event weaponPickup(Weapon:entity, Owner:entity)`                         | Runs when `Owner` picks up `Weapon` .                                                                                                                                                                                                                                            |
| `event weaponSwitched(Player:entity, OldWeapon:entity, NewWeapon:entity)` | Runs when `Player` switches from `OldWeapon` to `NewWeapon`.                                                                                                                                                                                                                     |
| `event entityCollision(Entity:entity, HitEntity:entity, CollisionData:collision)` | Runs when an entity tracked with `trackCollision(e)` or `trackCollision(e,f)` collides with any other entity. [CollisionData](https://wiki.facepunch.com/gmod/Structures/CollisionData) contains information like the velocity at which it occurred. In the case of `trackCollision(e,f)` `f` will run before the event.                                                                                                                                                                                                                |
| `event readCell(Address:number)` | Runs when a device tries to read from this E2 via wirelink or highspeed. Use `hispeedReturnValue(n)` to set a return value, or `hispeedSetError(n)` to indicate a read error.
| `event writeCell(Address:number, Value:number)` | Runs when a device tries to write to this E2 via wirelink or highspeed. Use `hispeedSetError(n)` to indicate a write error.


# Examples

## 📦 Using a prop

```golo
event playerUse(Player:entity, Entity:entity) {
    print(Player, "just used the prop", Entity)
}
```

## 💬 Chat Commands
This chip shows basic use of the chat event for chat commands.

```jsx
@persist Owner:entity
Owner = owner()

event chat(Player:entity, Message:string, _:number) {
    if (Player == Owner & Message[1] == "!") {
        const Rest = Message:sub(2)
        const Arguments = Rest:explode(" ")
        
        switch (Arguments[1, string]) {
            case "ping",
                print("pong!")
                break
            default,
                print("Unknown command: " + Arguments[1, string])
        }
    }
}
```

## 💣 Detecting Explosions
This chip detects any explosion damage to the chip and keeps track of it, and destroys itself if it takes too much damage.

```golo
@persist Health:number
Health = 1000

event entityDamage(Victim:entity, Damage:damage) {
    if (Victim == entity()) { # Check if damaged prop was the chip
        if (Damage:isType(_DMG_BLAST)) { # Only check for blast damage
            Health -= Damage:getAmount() # Subtract health by damage amount
            if (Health <= 0) {
                selfDestruct() # Destroy chip, out of health
            }
        }
    }
}
```
