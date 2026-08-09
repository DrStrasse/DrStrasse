This guide will tell you everything about creating a custom Expression2 Core for use in addons or pull requests.  

*Note that we will use types for documenting lua parameters and any with a question mark after the type like ``number?`` represents the ability to be left as nil.*

# Location
Custom E2 Cores will always need to be located at ``lua/entities/gmod_wire_expression2/core/custom``.  

An example file named "mycoolstuff.lua" would be located here:
``lua/entities/gmod_wire_expression2/core/custom/mycoolstuff.lua``

For files you want to run on the client (For E2Helper descriptions), prefix their filename with ``cl_``. So ``mycoolstuff.lua`` would turn into ``cl_mycoolstuff.lua``.

# Preprocessor
As you will note, looking at Expression2 core files they have some non-lua features like ``e2function ...``

This is because wiremod runs these functions after [preprocessing](https://en.wikipedia.org/wiki/Preprocessing) each E2 Core file, which abstracts away the manual lua function calls you'd have to do to create functions, so it is much easier to make E2Functions.

# Functionality
Inside of an Expression2 core, you'll have access to a lot of functions in the lua global table that allow you to create extensions, types and functions.

## Registering an extension
To register an extension, use ``E2Lib.RegisterExtension(string name, boolean default, string? description, string? warning)``.  

``name`` is the name of the module. For example [prop core] (https://github.com/wiremod/wire/blob/master/lua/entities/gmod_wire_expression2/core/custom/prop.lua) calls this with "propcore".  

``default`` is whether the extension should be enabled by default.  

``description`` is the description of the extension <!-- you'll see in the gui in your toolgun. I don't know what to call this. -->

``warning`` is a warning for any potential malicious stuff that may come with the extension.  

## Registering a type
Use ``registerType(string name, string id, any def, function? inputserializer, function? outputserializer, function typechecker)``

``def`` is the default value that your type will be in case of a user getting the type incorrectly  <!-- Needs verification (Like if they indexed an array with the wrong type that it contains). -->  

``inputserializer`` and ``outputserializer`` are functions that take an instance of your type and return a safe version for wiring inputs/outputs. In most cases these will be left as nil, but you can see an example in the [Angle](https://github.com/wiremod/wire/blob/a031e4d6c08f68818569f29c177c1e2df1faf9a9/lua/entities/gmod_wire_expression2/core/angle.lua#L5) type.

``typechecker`` is a function that takes a potential instance of a type and returns ``true`` if it is NOT an instance of the type.

## Registering a function
In the past, you had to use the ``registerFunction(string name, string parameters, string returns, function func, number cost, table paramnames)``, but now we have the Preprocessor that allows us to use the ``e2function <type> <name>...`` syntax you might have seen before in code.  

You still need to use this function in the case of making a "generic" function that can accept multiple types without being variadic (... functions).  

This is how to register a basic function using the preprocessor:  
```lua
e2function number getANumber()
    return math.random()
end
```

## Registering an operator
In the past you had to use the ``registerOperator`` function, which has the exact same arguments as ``registerFunction``.  
Using the preprocessor, registering an addition operation between two quaternions looks like this:
```lua
e2function quaternion operator+(quaternion lhs, quaternion rhs)
	return { lhs[1] + rhs[1], lhs[2] + rhs[2], lhs[3] + rhs[3], lhs[4] + rhs[4] }
end
```
See the full list of operators [here](https://github.com/wiremod/wire/blob/a031e4d6c08f68818569f29c177c1e2df1faf9a9/lua/entities/gmod_wire_expression2/core/extpp.lua#L17)

## Registering a constant
Use the ``E2Lib.registerConstant( string name, number value )`` function to register a constant.
Here's an example that registers _PIE.
```lua
E2Lib.registerConstant( "PIE", math.pi )
```

## Function aliases
The E2 Core Preprocessor also allows for creating *alias* functions, which are functions with different names but the exact same functionality.
```lua
e2function number getConstantE() = e2function number e()
```
This creates a function ``getConstantE()`` which does the same thing as ``e()``. Note you still need to include the arguments inside both functions.

## Setting op costs
To set operator costs, use the ``__e2setcost(number cost)`` function.  
Call it before your ``e2function ...`` calls.

# Creating documentation
To create documentation for an E2 core, like how we detailed in *Location*, create a file named cl_<mycore>.lua. This file will run on every client in order to create E2 descriptions for them.

## Function documentation
Once you are inside a clienside core file, documentation for a function may look like this.
```lua
E2Helper.Descriptions["print(...)"] = "A function that prints to your console"
E2Helper.Descriptions["helloWorld(t)"] = "A function that takes a table returns the number of items in it."
E2Helper.Descriptions["applyForce(e:v)"] = "Applies force on a prop with vector v" -- This is E:applyForce(v)
```
Note that these descriptions are in their e2helper/signature format, so they use typeids inside of the parenthesis for each parameter.  
There's also no documentation for return type.

<!-- ## Constant documentation
Make it happen someone :v)
-->

# Closure
This is about everything you need to know or would be useful for creating an E2 Core.  
Note you should always be careful with making your cores not lag the server as well as safe for users to not be able to abuse. There are many out there that are able to crash servers simply because of easy to abuse code.