### Description
The prop core functionality is used generally for manipulating [props][ref-prp-typ] using an E2 script within the [Garry's mod][ref-gmod] environment. Manipulation type can be anything like creating, deleting, teleporting, angling, gravity, inertia, buoyancy and much more. The data types are general for the [E2][ref-exp2] chip and you can [find them here][ref-e2-data]!
 
### What [console variables][ref-convar] can be used to setup it
```
sbox_E2_maxProps          : Controls the maximum amount of props spawned via E2 set this to `-1` to disable the limit.
sbox_E2_maxPropsPerSecond : Controls the maximum amount of props spawned for one second. Don't set this too high!  
sbox_E2_PropCore          : Controls enable/disable of the extension. Setup values are written below.
  0 : The extension is disabled.
  1 : Only admins can use the extension.
  2 : Players can affect their own props.
```

### Expression 2 API
All the function descriptions are available in the table below:

|         Instance creator         | Out | Description |
|:---------------------------------|:---:|:------------|
|`propSpawn`(![image][ref-e],![image][ref-a],![image][ref-n])|![image][ref-e]|Rotation, Frozen Spawns a prop with the model of the template entity and rotated to the angle given. If frozen is `0`, then it will spawn unfrozen.|
|`propSpawn`(![image][ref-e],![image][ref-n])|![image][ref-e]|Entity template, Frozen Spawns a prop with the model of the template entity. If frozen is `0`, then it will spawn unfrozen.|
|`propSpawn`(![image][ref-e],![image][ref-v],![image][ref-a],![image][ref-n])|![image][ref-e]|Position, Rotation, Frozen Spawns a prop with the model of the template entity, at the position denoted by the vector, and rotated to the angle given. If frozen is `0`, then it will spawn unfrozen.|
|`propSpawn`(![image][ref-e],![image][ref-v],![image][ref-n])|![image][ref-e]|Entity template, Position, Frozen Spawns a prop with the model of the template entity at the position denoted by the vector. If frozen is `0`, then it will spawn unfrozen.|
|`propSpawn`(![image][ref-s],![image][ref-a],![image][ref-n])|![image][ref-e]|Model path, Rotation, Frozen Spawns a prop with the model denoted by the string filepath and rotated to the angle given. If frozen is `0`, then it will spawn unfrozen.|
|`propSpawn`(![image][ref-s],![image][ref-n])|![image][ref-e]|Use the model string or a template entity to spawn a prop. You can set the position and/or the rotation as well. The last number indicates frozen/unfrozen.|
|`propSpawn`(![image][ref-s],![image][ref-v],![image][ref-a],![image][ref-n])|![image][ref-e]|Model path, Position, Rotation, Frozen Spawns a prop with the model denoted by the string file path, at the position denoted by the vector, and rotated to the angle given. If frozen is `0`, then it will spawn unfrozen.|
|`propSpawn`(![image][ref-s],![image][ref-v],![image][ref-n])|![image][ref-e]|Model path, Position, Frozen Spawns a prop with the model denoted by the string filepath at the position denoted by the vector. If frozen is `0`, then it will spawn unfrozen.|
|`seatSpawn`(![image][ref-s],![image][ref-n])|![image][ref-e]|Model path, Frozen Spawns a prop with the model denoted by the string filepath. If frozen is `0`, then it will spawn unfrozen.|
|`seatSpawn`(![image][ref-s],![image][ref-v],![image][ref-a],![image][ref-n])|![image][ref-e]|Model path, Frozen Spawns a prop with the model denoted by the string filepath. If frozen is `0`, then it will spawn unfrozen.|

|               Prop core method               | Out | Description |
|:---------------------------------------------|:---:|:------------|
|![image][ref-e]:`deparent`()||Unparents an entity, so it moves freely again.|
|![image][ref-e]:`parentTo`()||Parents one entity to another.|
|![image][ref-e]:`parentTo`(![image][ref-e])||Parents one entity to another.|
|![image][ref-e]:`propBreak`()||Breaks/Explodes breakable/explodable props (Useful for Mines).|
|![image][ref-e]:`propDelete`()||Deletes the specified prop.|
|![image][ref-e]:`propDrag`(![image][ref-n])||Passing `0` makes the entity not be affected by drag|
|![image][ref-e]:`propDraw`(![image][ref-n])||Passing `0` disables rendering for the entity (makes it really invisible)|
|![image][ref-e]:`propFreeze`(![image][ref-n])||Passing `0` unfreezes the entity, everything else freezes it.|
|![image][ref-e]:`propGetElasticity`()|![image][ref-n]|Gets prop's elasticity coefficient|
|![image][ref-e]:`propGetFriction`()|![image][ref-n]|Gets prop's friction coefficient|
|![image][ref-e]:`propGravity`(![image][ref-n])||Passing `0` makes the entity weightless, everything else makes it weighty.|
|![image][ref-e]:`propInertia`(![image][ref-v])||Sets the directional inertia|
|![image][ref-e]:`propMakePersistent`(![image][ref-n])||Setting to `1` will make the prop persistent.|
|![image][ref-e]:`propManipulate`(![image][ref-v],![image][ref-a],![image][ref-n],![image][ref-n],![image][ref-n])||Allows to do any single prop core function in one term (position, rotation, freeze, gravity, notsolid)|
|![image][ref-e]:`propNotSolid`(![image][ref-n])||Passing `0` makes the entity solid, everything else makes it non-solid.|
|![image][ref-e]:`propPhysicalMaterial`()|![image][ref-s]|Returns the surface material of a prop.|
|![image][ref-e]:`propPhysicalMaterial`(![image][ref-s])||Changes the surface material of a prop (eg. wood, metal, ... See [`Material_surface_properties`](https://developer.valvesoftware.com/wiki/Material_surface_properties) ).|
|![image][ref-e]:`propSetBuoyancy`(![image][ref-n])||Sets the prop's buoyancy ratio from `0` to `1`|
|![image][ref-e]:`propSetElasticity`(![image][ref-n])||Sets prop's elasticity coefficient (default is `1`)|
|![image][ref-e]:`propSetFriction`(![image][ref-n])||Sets prop's friction coefficient (default is `1`)|
|![image][ref-e]:`propSetVelocity`(![image][ref-v])||Sets the velocity of the prop for the next iteration|
|![image][ref-e]:`propSetVelocityInstant`(![image][ref-v])||Sets the initial velocity of the prop|
|![image][ref-e]:`propShadow`(![image][ref-n])||Passing `0` disables rendering for the entity's shadow|
|![image][ref-e]:`propStatic`(![image][ref-n])||Sets to `1` to make the entity static (disables movement, physgun, unfreeze, drive...) or `0` to cancel.|
|![image][ref-e]:`reposition`(![image][ref-v])||Deprecated. Kept for backwards-compatibility.|
|![image][ref-e]:`rerotate`(![image][ref-a])||Deprecated. Kept for backwards-compatibility.|
|![image][ref-e]:`setAng`(![image][ref-a])||Set the rotation of an entity.|
|![image][ref-e]:`setPos`(![image][ref-v])||Sets the position of an entity.|
|![image][ref-e]:`use`()||Simulates a player pressing their use key on the entity.|

|        General functions         | Out | Description |
|:---------------------------------|:---:|:------------|
|`propCanCreate`()|![image][ref-n]|Returns `1` when `propSpawn`() will successfully spawn a prop until the limit is reached.|
|![image][ref-r]:`propDelete`()|![image][ref-n]|Deletes all the props in the given array, returns the amount of props deleted.|
|![image][ref-t]:`propDelete`()|![image][ref-n]|Deletes all the props in the given table, returns the amount of props deleted.|
|`propDeleteAll`()||Removes all entities spawned by this `E2`|
|`propSpawnEffect`(![image][ref-n])||Set to `1` to enable prop spawn effect, `0` to disable.|
|`propSpawnUndo`(![image][ref-n])||Set to `0` to force prop removal on `E2` shutdown, and suppress Undo entries for props.|

[ref-a]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Angle.png
[ref-b]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Bone.png
[ref-c]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-ComplexNumber.png
[ref-e]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Entity.png
[ref-xm2]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Matrix2.png
[ref-m]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Matrix.png
[ref-xm4]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Matrix4.png
[ref-n]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Number.png
[ref-q]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Quaternion.png
[ref-r]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Array.png
[ref-s]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-String.png
[ref-t]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Table.png
[ref-xv2]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Vector2.png
[ref-v]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Vector.png
[ref-xv4]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-Vector4.png
[ref-xrd]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-RangerData.png
[ref-xwl]: https://raw.githubusercontent.com/wiki/wiremod/wire/Type-WireLink.png

[ref-prp-typ]: https://developer.valvesoftware.com/wiki/Prop_Types_Overview
[ref-e2-data]: https://github.com/wiremod/wire/wiki/Expression-2#Datatypes
[ref-gmod]: https://en.wikipedia.org/wiki/Garry%27s_Mod
[ref-exp2]: https://github.com/wiremod/wire/wiki/Expression-2
[ref-convar]: https://developer.valvesoftware.com/wiki/ConVar
