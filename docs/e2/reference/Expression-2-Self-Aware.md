# Expression 2: Self-Aware Functions  

With entity() you can use Entity-Support to get all the data from the expression-entity. With concmd() you can execute console commands.

Also, the chip has the ability to force itself. Forces aren't dispersed over a certain amount of time, all forces applied to an object within a tick are added up and then applied to the object. Force commands are best used with runOnTick(![Number](Type-Number.png "Number")) because you won't end up applying more than 1 force per tick and it is easier to do things like defy gravity.

This page lists all of the available functions used by the selfaware extension. To see examples, check [[Expression 2 Examples: Self Aware]].

| ...............Function...............       | Returns                             | Description                                                 |
| -------------- |:-----------------------------------:| ----------------------------------------------------------- |
| entity()        | ![Entity](Type-Entity.png "Entity") | Gets the entity of the expression            |
| concmd(![String](Type-String.png "Number"))        | ![Number](Type-Number.png "Number") | Takes a string and executes it in the console. Returns `1` if it succeeded and `0` if it failed. The client must enable this in the console with `wire_expression2_concmd 1`. The convar `wire_expression2_concmd_whitelist` allows you to choose which commands can be used. |
| applyForce(![Vector](Type-Vector.png "Number"))        |  | Applies force according to the vector given (Forces independently on each axis unlike a vector thruster) |
| applyOffsetForce(![Vector](Type-Vector.png "Number"),![Vector](Type-Vector.png "Number"))        |  | Applies force to the expression according to the first vector from the location of the second                  |
| applyAngForce(![Vector](Type-Vector.png "Vector"))        |  | Applies torque to the expression according to the given local angle|
| applyTorque(![Vector](Type-Vector.png "Number"))        |  | Applies torque to the expression according to the given local vector, representing the torque axis, magnitude and direction |
| selfDestruct()        |  | Removes the expression              |
| selfDestructAll()        |  | Removes the expression and all constrained props                  |
| ioOutputEntities(![String](Type-String.png "Number"))       | ![Array](Type-Array.png "Number") | Returns an array of all entities wired to the output ![String](Type-String.png "Number").              |
| ioInputEntity(![String](Type-String.png "Number"))        | ![Entity](Type-Entity.png "Number") | Returns the entity the input ![String](Type-String.png "Number") is wired to.  |
| ioSetOutput(![String](Type-String.png "Number"), *)        |  | Trigger the output ![String](Type-String.png "Number") of the `E2` with the value *. |
| ioGetInput*(![String](Type-String.png "Number"))        | **\*** | Get the value of the input ![String](Type-String.png "Number") of the `E2`.      |
| ![Entity](Type-Entity.png "Entity"):getName()        | ![String](Type-String.png "Number") | Returns the name of the `E2` ![Entity](Type-Entity.png "Entity").          |
| setName(![String](Type-String.png "Number"))       |  | Returns `1` if the expression was duplicated                  |
| changed(*)       | ![Number](Type-Number.png "Number") | Checks if the current input is different from the last input. The last value is saved based on the position in the code, so you need to be careful when using it in loops. Note internal value gets initialized as 0/empty string/..., so calling changed for the first time will return 1 unless the input is 0/empty string/... . Also note that due to E2 skipping later parts of conditionals when the result is already determined (ie `0 & <whatever>` is always 0, no need to execute `<whatever>`), you usually want `changed` to be first, ie `if(changed(A)&A)` (not `if(A&changed(A))`), to ensure it never gets skipped in this way and just gets to "see" certain values, ie just 1, never 0|
| select(![Number](Type-Number.png "Number"),*,...)  | * | Returns the ![Number](Type-Number.png "Number")-th value given after the index, *'s zero element otherwise. If you mix types, the behaviour is undefined.  |
| hash()        | ![Number](Type-Number.png "Number") | Returns a numerical hash using the code of the `E2` itself (Including comments). |
| hash(![String](Type-String.png "Number"))        | ![Number](Type-Number.png "Number") | Returns a numerical hash using the string specified. |
| hashNoComments()        | ![Number](Type-Number.png "Number") | Returns a numerical hash using the code of the `E2` itself (Excluding comments).         |



