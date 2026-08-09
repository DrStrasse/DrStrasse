>  Expression 2 is its own custom language, its syntax will take some time to get used to. While it does have some syntax inspiration from languages like [C](https://en.wikipedia.org/wiki/C_(programming_language)) or [TypeScript](https://www.typescriptlang.org/) you shouldn't expect the syntax to work the same as those languages.

> Also since Expression 2 is its own language, github highlighted should be taken with a grain of salt. We try to swap in other language's syntax highlighting to help visually convey the concepts but your best course of action is to copy any example code and paste it into the ingame editor.

---
<br>

| Table of Contents | Talks about... |
| --- | --- |
| [Directives & Preprocessing](#directives--preprocessing) | All Directives, Comments, `#ifdef` & related | 
| [Variables](#variables) | Variables, Datatypes, `let/local/const`, Operators | 
| [Scopes & Conditionals](#scopes--conditionals) | `if`, `elseif`, `else`, switch statements | 
| [Loops](#loops) | `for`, `while`, `do while`, `foreach`, `continue` | 
| [User Defined Functions](#user-defined-functions) | Basic Functions, Lambda Functions | 
| [Specialized functions \(misc\)](#specialized-functions-misc) | `#include`, Exception Handling, Events | 

<br>

# [Directives & Preprocessing](#directives-preprocessing)
### Directives
Directives are what explain what should be changed about the E2 at compile time.
They Follow this format:
```golo
@<NAME> <ARGS>

# Where <ARGS> is usually a whitespace delimited list of variables and their types. Like so:
@persist A:number B:string [C D E]:entity
```
<br>

Here is a table for all Expression2 Directives
| Directive | Use-case |
| :---: | --- |
| `@name` | Set the name of the chip that shows when hovering over it. Note this does not have to be the same as the filename. |
| `@input` | This is where you will define sources of information your chip will take in. |
| `@output` | This is the information your chip sends out to be used in other wire components. |
| `@persist` | Any Variable placed after this directive will stay defined between multiple chip operations |
| `@trigger` | The trigger directive can selectively enable or disable inputs from triggering executions. |
| `@model` | Adding the path to a prop model after this directive will cause your chip model to display as that prop. |
| `@strict` | This makes the E2 use current, more strict, execution, adds some new compiler features which aren't available on non-strict E2s, and allows you to get runtime validation errors previously unavailable, so you can quicker spot bugs in your code. (This was introduced so new compiler and function errors don't break old E2s, so don't take this directive as something optional. It's always recommended to use it!)
| `@autoupdate` | Using `@autoupdate` will enable auto updating. What this means is that whenever you paste a duplication of an E2 with autoupdate enabled, the E2 will check your files for a new version of that E2 and upload it. |
> [!IMPORTANT]
> Regarding `@autoupdate`:
>- Only works on saved E2s.
>- Auto Updating is disabled by default and will only work if `@autoupdate` is specified.
>- If you for some reason need to get an old version of your E2 from a dupe, you will have to temporarily change the name of your E2 so that the autoupdate feature doesn't find the file. Then it'll silently fail and leave you with the old code.

<br>

### Comments
- adding a `#` will comment out the rest of that line
- Multiline comments can be started with `#[` and ended with `]#`

```ruby
print("Hello World!") # Prints Hello World!

#[
    The print function requires a string
]#

```

<br>

### PreProcessing
The preprocessor commands `#ifdef`, `#ifndef`, and `#else` can be used to determine which code to execute based on whether a function exists or not.
```C++
#ifdef propSpawn(svan)
   print("You have propcore!")
#else
    error("This E2 requires propcore!")
#endif

```
Library creators can use the `#error` and `#warning` commands in combination with `#if(n)def` commands to generate compile-time errors or warnings. For instance:
```C++
#ifndef propSpawn(svan)
    #error This chip cannot run without propcore! Enable the `propcore` extension!
#endif

#ifndef superCoolFunction()
    #warning This E2 won't be as cool without superCoolFunction()
#endif

```

<br>

## [Variables](#variables)
In Expression 2, every variable must begin with a capital letter.
```ruby
# COMPILE ERROR!
varibleName = 1 

#VALID
VaribleName = 1
```

### DataTypes
There are four fundamental types in Expression2, namely:
*  `number` - represents numerical data and also truthiness, where any non-zero value is considered "truthy" *(see [Scopes & Conditionals](#scopes--conditionals))*.
*  `string` - represents a simple string enclosed in quotation marks. It can be multiline.
*  `array` - represents a sequence of items and can't contain other arrays or tables. Similar to a `List` in other programming languages.
*  `table` - represents a typed table that can have arbitrary string and numerical keys. Similar to a `Dictionary` in other programming languages.
* `function` - represents a user-defined function that you can call

These four basic types are utilized in virtually every Expression2 script. The table below presents all of the types supported by Expression2.
| Shorthand | Datatype      |
| --------- | ------------- |
| N         | Number        |
| S         | String        |
| R         | Array         |
| T         | Table         |
| F         | Function      |
| V         | Vector        |
| E         | Entity        |
| A         | Angle         |
| RD        | RangerData    |
| B         | Bone          |
| M2        | Matrix2       |
| XWL       | Wirelink      |
| C         | ComplexNumber |
| Q         | Quaternion    |

Unlike dynamic programming languages, Expression2 is a statically-typed language, meaning that variables cannot be assigned to different types.
```ruby
# COMPILE ERROR!
Variable = 55
Variable = "Fifty Five"

# VALID
MyList = array(1, 2, 3, 4)
MyList = array(5, 6, 7, 8)
```

Number literals can be created in binary or hexadecimal by prefixing the number with `0b` for binary or `0x` for hexadecimal.
```ruby
print(0b10) # prints "2"
print(0x16) # prints "22"
```

Hexadecimal and unicode can be used in string literals using `\xXX` and `\u{XXXXXX}` where `\u` requires between 1 and 6 hexadecimal characters less than `10ffff`.
```ruby
print("\x48\x65\x6c\x6c\x6f\x2c\x20\x57\x6f\x72\x6c\x64\x21") # prints "Hello, World!"
print("\u{2615}") # prints "☕"
```

### Scoping Variables
So far we've talked about global variables, but if you want to create a variable only accessible inside the current scope, use the `let` keyword.

> [!NOTE]
> `let` is a new keyword replacing `local`  
> There's no difference between the two at this moment, but `let` reserves the right to make potentially necessary breaking changes.  
> So if you see `local` in code, it just means `let`.

```golo
if (1) {
    let MyVar = 55
}
print(MyVar)
```

> [!CAUTION]
> **ERROR**: Undefined variable (MyVar)

#### Constant Variables
If you don't plan on modifying the variable, you can define it as `const`.
```ts
const X = "Hi!"
X = "Hello!"
```

> [!CAUTION]
> **ERROR**: Cannot redeclare constant variable

<br>
<br>

## Operators
Expression2 supports the following operators in the order of precedence (from highest to lowest priority):
| Priority | Operator | Syntax | Description |
| --- | --- | --- | --- |
| 1 | Increment | `Var++` | Causes `Var` to increase by 1 |
| 1 | Decrement | `Var--` | Causes `Var` to decrease by 1 |
| 2 | Literals |  | Hardcoded numbers/strings |
| 2 | Trigger | `~Input` | Outputs `1` if the following input caused the current execution |
| 2 | Delta | `$Var` | Outputs the change in `Var` since the last call of `$Var` |
| 2 | Connected Wires | `->InOut` | is `InOut` connect to the wire I/O? |
| 3 | Parenthesis | `()` | can act as a function call or be used in math equations to control order of operations |
| 3 | Function Calls | `function(Var)` | Calls said function with given `Var` |
| 4 | Method Calls | `Var:method(...)` | calls the `method()` function on the given `Var` |
| 4 | Indexing | `Var[Value,type]` | Will attempt to locate the provided `Value` with the provided `type` within the provided `Var` |
| 5 | Unary plus | `+Var` | Returns the identity (same value) of `Var` |
| 5 | Unary minus | `-Var` | Negates the value of `Var` |
| 5 | Logical NOT | `!Var` | if something returns true, attaching this operator will make it return false |
| 6 | Exponentiation | `A ^ B` | Raised `A` to the power of `B` |
| 7 | Multiplication | `A * B` | Multiplies `A` by `B` |
| 7 | Division | `A / B` | Divides `A` by `B` |
| 7 | Modulo | `A % B` | Returns the remainder of division |
| 8 | Addition | `A + B` | Adds `A` and `B` |
| 8 | Subtraction | `A - B` | Subtracts `A` and `B` |
| 9 | Binary Left Shift | `A << B` | Equivalent to `A * (2^B)` |
| 9 | Binary Right Shift | `A >> B` | Equivalent to `floor(A/(2^B))` |
| 10 | Greater Than | `A > B` | if `A`'s value is more than `B` |
| 10 | Less Than | `A < B` | if `A`'s value is less than `B` |
| 10 | Greater Than or Equal to | `A >= B` | if `A`'s value is more than or equal to `B` |
| 10 | Less Than or Equal to | `A <= B` | if `A`'s value is less than or equal to `B` |
| 11 | Equals | `A == B` | if `A`'s value equals `B`'s value |
| 11 | NOT Equals | `A != B` | if `A` doesn't equal the value of `B` |
| 12 | Binary XOR | `A ^^ B` | Returns the binary XOR of `A` and `B`. |
| 13 | Binary AND | `A && B` | Note that this is reversed with the "classical" `&` operator |
| 14 | Binary OR | `A \|\| B` | Note that this is reversed with the "classical" `\|` operator |
| 15 | Logical AND | `A & B` | Note that this is reversed with the "classical" `&&` operator |
| 16 | Logical OR | `A \| B` | Note that this is reversed with the "classical" `\|\|` operator |
| 17 | Ternary Conditional | `A ? B : C` | Evaluates to `B` if `A` is truthy, otherwise `C` |
| 17 | Binary Conditional | `A ?: B` | Equivalent to `A ? A : B` |
| 18 | Assignment | `A = B` | The value of `A` now equals the value of `B` |

It's important to note that some operators work with other types, such as vector arithmetic with `+`, `-`, `*`, and `/` (per-component), and string concatenation with `+` (although `format` or `concat` should be used for most concatenation operations).

<br>
<br>

## Scopes & Conditionals
Scopes restrict variables to a particular code block (usually enclosed by curly braces `{ <CODE HERE> }`). The highest level of scope outside of any blocks is called the "global" scope, where `@persist`, `@inputs`, and `@outputs` variables are stored, allowing them to be accessed from anywhere in the code.

> [!Important]
> E2 does not use typical booleans, and instead uses *truthiness* (or [*truth value*](https://en.wikipedia.org/wiki/Truth_value#Computing)). In place of booleans, most E2 expressions use `0` to represent *falsiness* and `1` or non-zero to represent *truthiness*.
>
> However, you're not limited to using numbers. Every built-in type in E2 has a truth value test to it, which determines an object's truthiness. For example, the string `""` is falsy while `"0"` is truthy. Empty arrays and tables are falsy while filled ones are truthy.
>
> Generally, you can expect that for any type, it's falsy value is its default, uninitialized value, also called a *zero* value.

<br>

### `if`
An `if` statement executes a block of code only if a condition is met (i.e., the passed variable is non-zero).
```ruby
if (1) {
    print("This will run")
}
```

<br>

### `elseif`
By using `elseif`, you can chain conditions together.
```ruby
if (0) {
    print("never runs since 0 does not meet condition")
} elseif (2) {
    print("This will run since the first if statement failed AND this if statement passes ")
}
```

<br>

### `else`
`else` is used to handle cases where none of the conditions are met.
```ruby
if (0) {
    print("This will not run since (0) is not truthy")
} else {
    print("This will always run")
}
```

<br>

### `Switch` Statements
A switch statement is similar to an if chain and allows for "fallthrough" behavior. If you omit the break statement after each case, it will execute every case underneath it (even if the condition isn't met) until it finds a `break` or reaches the end of the switch block.

> [!NOTE]
> For performance reasons, you should avoid using switch statements when possible.

```ruby
switch (Var) {
    case 2,
        print("Var is 2")
        break

    case 3,
        print("Var is 3")
        break

    case 4,
        print("Var is 4") # Will fall through to the default case as well

    default,
        print("Var is not 2 or 3")
}
```
<details>
    <summary>Equivalent code using if statements</summary>

```ruby
if(Var == 2) {
    print("Var is 2")
} elseif(Var == 3) {
    print("Var is 3")
} else {
    if(Var == 4) {
        print("Var is 4")
    }
    print("Var is not 2 or 3")
}
```

</details>

<br>
<br>

## Loops
### `for`
The `for` loop consists of three numbers: the first represents the current iteration count, the second represents the iteration count at which the loop should end, and the optional third number represents the optional increment *step* value at each iteration. By default, the *step* count is 1.

```ruby
#This will call the code 5 times (1 - 5 inclusive). In this case, the third argument is redundant.
for (I = 1, 5, 1) {
    ...
}
```

> [!NOTE]
> If you don't need to keep track of the iteration count in a for loop, you can discard the iteration variable to save a bit of performance.

<br>

### `while`
A while loop will execute the code within its block as long as the specified condition is true. It's important to note that while loops can be unstable without `perf()` included in the conditional statement.
```ruby
while (perf(80)){
    ...
}
```

<br>

### `do while`
A `do while` loop is similar to a `while` loop, but it will always execute its block of code at least once. It checks the condition at the end of each iteration to determine whether to continue or exit the loop.
```ts
do {
    ...
} while (perf(80))
```

<br>

### `foreach`
The `foreach` loop allows you to iterate through all the values of an array or table.
```csharp
foreach(Key:number, Value:entity = findToArray()) {
    ...
}
```

It's recommended to annotate the type of keys when iterating through a table using `foreach`. By default, `foreach` on a table will iterate through string keys. To iterate through number keys, annotate with `:number`.

```csharp
foreach(Key:string, Value:number = MyTable) {}
```

<br>

### `break`
The `break` keyword allows you to exit a loop prematurely.
```ruby
foreach(K, Ply:entity = players()) {
    if (Ply:distance(entity()) < 400) {
        break
    }
    # Haven't found a player closer than 400 units yet
}
```

<br>

### `continue`
The `continue` keyword allows you to skip a single iteration of a loop.
```ts
for (I = 1, 5) {
    if (I % 2 == 0) {
        continue  # Skip even numbers (You should use the for loop step parameter instead, though).
    } 
}
```

<br>

## User Defined Functions
Functions help to improve code organization and readability by allowing you to break down code into reusable and modular components.

### Basic Functions
A function can be defined using the following syntax:
```js
function helloWorld() {
    print("Hello world!")
}

helloWorld()
```
This function will have a return type of `void`, which means that it does not output a value.

#### Function Parameters
> [!NOTE]
> Function parameters are assumed to be numbers by default, unless you specify a different data type using the format `<NAME>:<TYPE>`.  
> This behavior shouldn't be relied on and is deprecated, though.
```js
function hello(Text:string) {
    print("Hello ", Text)
}

hello("World!")
```

#### Function Returns
You can specify the return type of a function to let you pass values from it to another piece of code.
```ts
function string compliment(Name:string) {
    return "You look nice, " + Name + "!"
}

print(compliment(owner():name()))
```
> [!IMPORTANT]
> You are required to make sure your function returns at the end of all code paths. The editor will error if you do not. If you're not sure where to place the return, put it at the very end of your function.

#### Variadic Parameters
Variadic parameters allow you to call a function with a varying amount of parameters.  
This is essentially just a function that takes an array, but it allows you to pass the arguments to the function directly rather than needing to wrap the arguments in an `array()`

```ruby
# This function calls printColor with a prefix `[neat] `.
function printMessage(...Args:array) {
	printColor(  array(vec(0, 172, 0), "[neat] ", vec(255)):add(Args) )
}

printMessage("Cool! Here's a number: ", randint(1, 27), ".")
```
You can also define the variadic parameter as a table, which allows you to use arrays and tables in the function call.
```ruby
# Sums all arrays together
function number arraySum(...Args:table) {
    local Sum = 0
    foreach(_:number, R:array = Args) {
        Sum += R:sum()
    }
    return Sum
}

print(arraySum(array(6, 1), array(11))) # Prints "18"
```

#### User-Defined Methods
(Formerly called meta-functions)

A method is prefixed by a type followed by a colon. This is functionally identical to a normal function, but looks nicer.
```golo
function entity:hello() {
    print("Hello " + This:name())
}

owner():hello() # Prints "Hello " followed by your username
``` 

### Lambda Functions

Lambdas are functions that can be stored in variables, also known as [first-class functions](https://en.wikipedia.org/wiki/First-class_function). For simplicity, you should use [normal functions](#basic-functions) when you don't need the flexibility of lambdas.

Lambdas are quite simple to use. Its syntax is similar to creating a function, and you call a lambda similarly to a normal function.
```golo
let MyLambda = function(S:string) {
    print(S)
}

MyLambda("Hello, World!") # Prints "Hello, World!"
```

Lambdas automatically determine their return type when you define them. To retrieve the value of a lambda return, you'll need to specify the return type in `[`brackets`]` after the lambda call.

```golo
let Runs = 0
let GetRun = function() {
    Runs++
    return Runs
}

print(GetRun()[number])

print(GetRun()) # ERROR! GetRun is assumed to return void here
```

Lambdas work just like any other type, so you can pass them to functions and return them. You can also define a lambda without storing them and pass them directly (known as a *function literal*).

```golo
let Wrapper = function(Func:function) {
    return function() { # Create and return function literal
        print("Wrapped!")
        Func()
    }
}

let Wrapped = Wrapper(function() { # Create and pass a function literal
    print("Hello, World!")
})[function]

Wrapped() # Prints "Wrapped!" and "Hello, World!"
```
*See also: [E2 Guide: Lambdas](/wiremod/wire/wiki/E2-Guide:-Lambdas)*
### Calling functions with strings
> [!WARNING]
> String calling is deprecated and will not be supported in the future. Look above to [Lambda Functions](#lambda-functions) to use the replacement.

Using string calls to dynamically call functions should be avoided due to their performance cost and hacky nature. ~~However, this can serve as a substitute for "delegates" or "lambdas" from other languages until they are available.~~
```golo
let F = "print"
F("Hello world!") # Same as print("Hello world!")

let X = "health"
let OwnerHealth = X(owner())[number] # Same as owner():health()
```

> [!WARNING]
> These are deprecated and have been superceded by lambdas.
> Using them will error on `@strict` in the future.

<br>
<br>

## Specialized functions \(misc\)
### `#include`
The `#include` syntax in E2 is similar to that of C and C++. When an `#include` statement is encountered, E2 will execute the code in the specified file. It's recommended to put the `#include` statement inside an `if(first())` statement, and note that despite its appearance, it is parsed like a normal statement and is not related to the preprocessor.

```golo
# example_lib.txt
function doStuff() {
    print("Hello world!")
}
```

```ruby
if (first()) {
    #include "example_lib"
    #^^ make sure not to include .txt ^^

    # Now you can use functions and global variables from the "example_lib" file.
    doStuff()
}
```

### Exception Handling
> [!NOTE]
> It is STRONGLY suggested to always leave the strict directive in your e2.
> At this point, some compiler features are only available with strict mode, thus non-strict mode is only left to support backwards compability.

By default, Expression 2 does not often throw errors; instead, it will silently fail and return a default value on function calls. However, if you enable the `@strict` directive, these errors will be thrown as proper runtime errors. To handle them, you should use `try` and `catch` blocks.
```golo
try { # < -- If an error occurs in this block, it will exit the block and call the catch {} block, passing the error message string.
    error("Unexpected error")
} catch(E:string) { # < -- Can rename E to anything. It just stores the error message.
    assert(E == "Unexpected error")
}
```
However, it's important to note that this only covers errors that occur within Expression 2 and not internal Lua errors caused by E2 extensions.


### Events
*Main article: [Expression 2 Events](/wiremod/wire/wiki/Expression-2-Events)*

Expression 2 inherited a problematic "clk" system from E1, which involved re-running the code and checking a variable to determine what caused it to run, leading to confusion and headaches. To address this issue, the event system was created as a replacement.

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
See all events on the [Expression2 Events](/wiremod/wire/wiki/Expression-2-Events) page.

---