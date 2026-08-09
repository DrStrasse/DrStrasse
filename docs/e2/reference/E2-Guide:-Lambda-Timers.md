This articles covers in-depth usage of lambda timers. If you haven't already seen [basic usage in the syntax guide](https://github.com/wiremod/wire/wiki/Expression-2-Syntax#lambda-functions), you should do so before reading ahead.

Before learning about lambda timers, we strongly suggest you to learn about [lambda functions](https://github.com/wiremod/wire/wiki/E2-Guide:-Lambdas), if you haven't already.

# Introduction
Lambda timers (or callback timers) are useful concept in programming. Mainly in frontend and game development.

You'll often want to do something after a delay or repeatedly at an interval in E2. This is where timers come in. 

The **lambda** timers came as a replacement for old timer system, which previously executed the whole global scope of e2 chip on each execution. That is not the way it should be done :smirk: 

## Basic
Lambda timers are constructs, which essentially have only few parts.
* Name > Name of the timer, by which you, later on, can interact with (stop/start/restart/etc)
* Delay > Delay, (**IN SECONDS**) with which should the timer be executed. The delay can never be below the tick interval.
* Repetitions > How many repetitions should the timer do before destroying itself? If less then 0 - timer will run indefinitely.
* Lambda function > The part that makes the lambda timer shine. Instead of re-running the whole e2 - lambda timer executes the passed [lambda function](https://github.com/wiremod/wire/wiki/E2-Guide:-Lambdas).

# Explanation on examples

Timers have a few forms, so let's look over them briefly.
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

# Why use them?
`I'm already used to the old timer system. Why are you forcing me to use lambda timers?` - Great question! While it may feel better to use something you're familiar with - we, as wiremod team, always trying to bring the best practices to all our elements. E2 included.

Thus, the old timer system forced the e2 chips to execute the global scope repeatedly, which is not the way it should've worked. New timers, in pair with [@strict](https://github.com/wiremod/wire/wiki/Expression-2-Directives#strict) and [@trigger none](https://github.com/wiremod/wire/wiki/Expression-2-Directives#strict) directives allows for conventional global scope programming. Similar, how you would do that in any other language.