This articles covers in-depth usage of *lambdas*, E2's function objects. If you haven't already seen [basic usage in the syntax guide](/wiremod/wire/wiki/Expression-2-Syntax#lambda-functions), you should do so before reading ahead.

## Table of Contents
**[Introduction](#introduction)**  
  •  [Functions as Data](#functions-as-data-)  
  •  [Closures](#closures-)

**[Examples](#examples)**  
  •  [Chat Command Look-Up Table](#chat-command-look-up-table)

# Introduction
The ability to create variables and store things in them is a vital component of many programming languages.  The ability to create functions that take arguments is also rather paradigm.  But what if you encounter a scenario where you yearn to do both in the same feature?

If you want to do any of the following...
- Store a function in a variable
- Pass a function to another function
- Store a function on a table/entity
- Store state inside a function

Lambdas are your solution!

## Functions as data 🧮
A function is just a group of code that you can run whenever you want.
If you wanted to create a function that printed out "hello" whenever you ran it, you'd create it like this:
```ts
function() {
	print("Hello")
}
```
This is pretty useless on its own, though, because it creates a function and doesn't store it anywhere, so we usually assign that to a variable.
```ts
MyFunction = function() {
	print("Hello")
}
```
Now, you can use function call syntax on *MyFunction* to call the function it's assigned to.
```ruby
MyFunction() # prints "Hello"
```
That seems cool and all, but since *MyFunction* is technically a variable, that means we can store its value to multiple other places.
```ruby
MyOtherFunction = MyFunction
MyOtherFunction() # prints "Hello", too!
MyTable[1] = MyFunction
MyTable[1, function]() # Does what you'd expect
```
And finally, since it acts like a variable, we can also pass it to other functions, like `timer`.
```ruby
timer(1, MyFunction) # Prints "Hello" after 1 second
```
Now, all of that is to say, we could also just skip the part about doing `MyFunction = ` and pass the *function literal* directly to the `timer` function.
```r
timer(1, function() {
	print("Hello")
}) # This code is equivalent to MyFunction, so it's functionally the same
```
Lambdas are just another name for "functions without a name", like we have demonstrated here.

Because of how E2 works, you should know that global variables are accessible in any scope. That means you can modify global variables in functions, too.
```r
@outputs Out
timer(1, 0, function() { # The second argument here specifies repetitions. 0 means it repeats forever.
	Out++ # Out will be incremented by 1 each second
})
```
And because functions can be made anywhere, you have free reign to place them right next to the code that's most relevant to them.
```ruby
@inputs In
@outputs Out
event input(_:string) {
	if(!In) { exit() } # Only trigger if In is active
	if(!Out & !timerExists("auto off")) {
		Out = 1 # Turn on the output
		timer("auto off", 1, function() { # We use a named timer to avoid overlapping timers
			Out = 0 #Turn off the output after 1 second
		})
	}
}
```
If you wanted a single timer to run most of your code at a specific interval, you'd simply encapsulate all of that code in a timer.
```ruby
@name Mario Party Dice roller (but not RNG)
@inputs Stop
@outputs Out
@trigger none
@strict

holoCreate(1)
Out = 0
let Value = 0

timer("main", 0.05, 0, function() { # Runs every 0.05 seconds infinitely
	Value = (Value + 1) % 100
	Out = (Value % 10 + 1) # Value rotates from 1 - 10
	
	let Ang = Value / 100 * 360

	let Color = hsv2rgb(Ang, 1, 1)
	holoColor(1, Color)
	
	let C = Ang - 180
	holoAng(1, ang(C, -C, 0))
})

event input(InputName:string) {
	if(InputName == "Stop") {
		if(Stop) {# Stops the timer when the input is on
			timerPause("main")
		} else {
			timerResume("main")
		}
	}
}
```

## Closures 📦

[Closures](https://en.wikipedia.org/wiki/Closure_(computer_programming)) are a feature in programming that allow functions to pass local values to new functions. Consider the following scenario, where we have a function that inputs a number, and returns a function that uses that input, without being passed the input directly.
```ruby
function function makeIncrementer(X:number) {
    return function() {
        X += 1
        return X
    }
}

let IncrementFromOne = makeIncrementer(1)

print(IncrementFromOne()[number]) # prints 2
print(IncrementFromOne()[number]) # prints 3
```
So, what just happened here? 
- We called `makeIncrementer` with an argument of `X = 1`
- `makeIncrementer` returned a function that needs the enclosing scope it was created in to work (it relies on `X`), hence the name "closure".
- When we call `IncrementFromOne`, it increments the captured `X` and returns the result of that.
- Each subsequent call, `IncrementFromOne` remembers what `X` was last time and returns increasing values accordingly!

You can depend on this behavior being isolated across two different calls of `MakeIncrementer`. Consider if we wanted two "incrementers" starting from different numbers. Conventional logic may think that one will overwrite the other, but you'll be pleasantly surprised to find that's not the case.
```ruby
let IncrementFromZero = makeIncrementer(0)

print(IncrementFromZero()[number]) # Prints 1

let IncrementFromTen = makeIncrementer(10)

print(IncrementFromTen()[number]) # Prints 11
print(IncrementFromZero()[number]) # Prints 2
print(IncrementFromTen()[number]) # Prints 12
```
So, what we see here is that if we define a function, all the local variables (called *upvalues*) inside that function can be used as though they were its own, even if they aren't defined globally or in the function itself.

### ⚠️ BUT!
Be careful about what kinds of objects you try to capture with closures.  If they aren't *primitives* (numbers or strings), you'll end up capturing a reference to the object rather than a true copy of it!  This may lead to maddening "wtf is happening" kinds of behavior!
```ruby
function function makeEvilIncrementer(T:table) {
    return function() {
        T["x", number] = ["x", number] + 1
        return T["x", number]
    }
}

let NumberInATable = table("x" = 1)

let EvilIncrementer1 = makeEvilIncrementer(NumberInATable)
let EvilIncrementer2 = makeEvilIncrementer(NumberInATable)

print(EvilIncrementer1()[number]) # Prints 2
print(EvilIncrementer2()[number]) # Prints 3 (????)

NumberInATable["x", number] = -1

print(EvilIncrementer2()[number]) # 0 (???????)
```
The closure's upvalue is only a reference to the original `NumberInATable`, and NOT a reference to a copy.  For non-primitive values, making a copy is your responsibility!

So how do we fix the above behavior?
Tables have a convenient method called `:clone()` that makes copying them easy:
```ruby
function function makeLessEvilIncrementer(T:table) {
    T = T:clone()       # redefine the upvalue as a copy of itself
    return function() { # now carry on as usual
        T["x", number] = ["x", number] + 1
        return T["x", number]
    }
}
```
Careful using this method as a bandaid fix though—deep copying a table can get expensive fast!


<!--
## Timers
> 🔰 Beginner

You'll often want to do something after a delay or repeatedly at an interval in E2. This is where timers come in. Timers have a few forms, so let's look over them briefly.
```rb
let MyAction = function() {
    print("Hi!")
}

timer(1, MyAction) # number delay, function callback
timer("my timer", 2, MyAction) # string name, number delay, function callback
timer("my other timer", 3, 1, MyAction) # string name, number delay, number repetitions, function callback
```
The first form creates a one-use, "anonymous" timer, which doesn't have an identifier. This is good for one-offs where you aren't concerned too much about controlling the timer. The first argument is the delay *in seconds*, which the second is the function to run after the timer is up.

The second form creates a one-use timer with a name. This lets you stop the timer prematurely or overwrite it. Consider if we did,
```rb
timer("my timer", 1, function() {
    print("Hello!")
})

timer("my timer", 3, function () {
    print("Hello again!")
})
```
Only the second timer (`"Hello Again!"`) would execute, since you're using the same identifier, which gets overwritten.
> [!NOTE]
> You do not have to have completely unique names for every timer in all your E2s; timer names are limited to the E2 itself.

Lastly, the third form has a name, delay in seconds, and the amount of repetitions. By default, timers only execute once. This lets you specify them to execute 5, 100, or more times. You can create an infinite timer by putting the number of repetitions as 0.
```rb
@outputs Lights
Lights = 1
timer("strobe", 0.5, 0, function() { # half-second timer that runs an infinite amount of repetitions
    Lights = !Lights # Invert the value of Lights
})
```
Timers are restricted to a minimum of `0.01` delay. Anything lower will be clamped to that value.
> [!IMPORTANT]
> Timers are executed every server tick. For most servers (66-tick), that means ever timer is executed every 0.0152 seconds, the tick interval. If you need a timer to execute before another one, make sure that your delay is long enough. If your delay is below the tick interval, your timer will execute the next tick. The following code demonstrates two timers that actually execute at the same time.
> ```ruby
> @strict
> let TimeA = 0
> let TimeB = 0
>
> timer(0.011, function() {
>     TimeA = curtime()
>     if(TimeB) {
>         print(TimeA == TimeB ? "Same time!" : "Different time!", TimeA)
>     }
> }
>
> timer(0.01, function() {
>     TimeB = curtime()
>     if(TimeA) {
>         print(TimeB == TimeA ? "Same time!" : "Different time!", TimeB)
>     }
> }
> ```
-->
# Examples
## Chat Command Look-up Table
> 🟢 Easy

If you're familiar with [using look-up tables in E2](/wiremod/wire/wiki/E2:-Tips-and-Tricks#lookup-tables), you can use function lambdas to create a chat command processor that you can easily extend and modify.

First, let's start with making our table to store functions, the command "keyword", and register the `chat` event. Inside the event, I'll put some code that checks if the *Message* starts with the keyword. Since it's only one character, I can cheat here by simply using array indexing to get the first character.
```ruby
@strict
const Functions = table()
const Keyword = "/"

event chat(Player:entity, Message:string, _:number) {
    if(Message[1] == Keyword) {

    }
}
```

Now inside of the if statement, I'll put this code which will split the message after the keyword and also split apart the command from the rest of the arguments. Then, I'll have another if statement to check if the command exists inside the function table. If it does, I'll run it and pass the leftover array of arguments. I'll also add a warning if the user inputs a bad command, which isn't necessary but may be nice.
```ruby
let Args = Message:sub(2):explode(" ") # Skip the first character ("/") and split the string into an array
let Command = Args:shiftString():lower() # Removes and returns the first element, and shifts everything down to compensate
if(Functions:exists(Command)) {
    Functions[Command, function](Args)
} else {
    print("Unknown command: " + Command)
}
```

If we were to run this now, we'll just keep getting the unknown command error because, of course, we haven't made any commands yet. So, let's see how simple it is to add new ones. I'll define some basic ones. At the top of our code, right after where we initialized `Functions`, we can add new functions just like so:
```ruby
Functions["ping", function] = function(_:array) {
    print("Pong!")
}

Functions["hurt", function] = function(Args:array) {
    let Name = Args[1, string]
    let Player = findPlayerByName(Name)
    if(Player) {
        let Damage = Args[2, string]:toNumber()
        try {
            Player:takeDamage(Damage)
        } catch(_:string) {
            print("Damage is not allowed!")
        }
    } else {
        print(format("Couldn't find player %q", Name))
    }
}   
```
> [!IMPORTANT]
> The array argument is required even when it's not used. Your return type and function parameters need to be consistent for this to work, or you'll run into an error.

Now with all this together, we should be able to run our `ping` and `hurt` commands. You can add more commands just by adding a new function to the table.

<details><Summary>Full code</Summary>

```ruby
@strict
const Functions = table()
const Keyword = "/"

Functions["ping"] = function(_:array) {
    print("Pong!")
}

Functions["hurt"] = function(Args:array) {
    let Name = Args[1, string]
    let Player = findPlayerByName(Name)
    if(Player) {
        let Damage = Args[2, string]:toNumber()
        try {
            print("Trying to hurt")
            Player:takeDamage(Damage)
        } catch(_:string) {
            print("Damage is not allowed!")
        }
    } else {
        print(format("Couldn't find player %q", Name))
    }
}  

event chat(Player:entity, Message:string, _:number) {
    if(Message[1] == Keyword) {
        let Args = Message:sub(2):explode(" ") # Skip the first character ("/") and split the string into an array
        let Command = Args:shiftString():lower() # Removes and returns the first element, and shifts everything down to compensate
        if(Functions:exists(Command)) {
            print("Calling " + Command)
            Functions[Command, function](Args)
        } else {
            print("Unknown command: " + Command)
        }
    }
}

```
</details>

