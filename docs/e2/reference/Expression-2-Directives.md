# Directives
Directives allow you to control important properties about E2 chips, such as their name, inputs, outputs, and more.

## ``@name``
Define the name of the E2 chip to show when hovering over it.

**Example**
```yaml
@name My E2 Chip
```
## ``@inputs``
Define inputs to use with the wire system alongside their types.

**Example**
```yaml
@inputs X Y:string [Z W]:number
```

## ``@outputs``
Define outputs to use with the wire system alongside their types.

**Example**
```yaml
@outputs X Y:string [Z W]:number
```

## ``@persist``
Define a variable to persist across multiple executions.  
Otherwise variables will reset to their default values.

**Example**
```yaml
@persist X Y:string [Z W]:number
```

## ``@trigger``
The trigger directive can selectively enable or disable inputs from triggering executions.
Possible values are all/none, but also a list of inputs.
You usually will not need to worry about this.

**Example**
```yaml
@trigger all
# or
@trigger X Y
```

## ``@model``
Sets the model of the E2 chip.
**Example**
```yaml
@model path/to/prop/model.mdl
```

## ``@autoupdate``
Using the autoupdate directive will enable auto updating. What this means is that whenever you paste a duplication of an E2 with autoupdate enabled, the E2 will check your files for a new version of that E2 and upload it.
Note:
* Only works on saved E2s.
* To disable autoupdate, simply don't write @autoupdate
* If you for some reason need to get an old version of your E2 from a dupe, you will have to temporarily change the name of your E2 so that the autoupdate feature doesn't find the file. Then it'll silently fail and leave you with the old code.

## ``@strict``
> [!NOTE]
> It is STRONGLY suggested to always leave the strict directive in your e2.
> At this point, some compiler features are only available with strict mode, thus non-strict mode is only left to support backwards compability.

This makes E2 throw [runtime errors](https://github.com/wiremod/wire/wiki/Expression-2-Syntax#exception-handling) on edge cases, unsafe practices, and other things that might be the source of bugs. (But also brings a lot of new features and optimizations)

Take this example for instance:
```golo
E = propSpawn("some/custom/model.mdl", entity():pos(), 1)
E:applyForce( vec(10000, 0, 0) )
```
If the server doesn't have `"some/custom/model.mdl"`, you'll end up with an invalid entity stored in `E`.

Without `@strict`, this silently fails and tries to carry on like nothing happened.  
However, WITH `@strict`, it will throw a **hard error** and **shut down the E2** if not handled in a [try/catch](https://github.com/wiremod/wire/wiki/Expression-2-Syntax#exception-handling) block.