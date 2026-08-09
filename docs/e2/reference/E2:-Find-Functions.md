This articles covers how to find entities in the world using E2's find functions.

## Table of Contents
* **[Important: Rate Limits](#rate-limits)**
* **[Usage](#usage)**  
    * [Filters](#find-filters)  
        * _[Example](#example)_
        * _[Filter Flowchart](#filter-flowchart)_
    * [Queries](#find-queries)
    * [Clipping](#3-clipping)
    * [Results](#4-results)
* [Examples](#examples)

# Important: Rate Limits
To prevent players from crashing or lagging servers, E2 limits the rate you can perform find queries with.  
These queries are any find functions that return one or more entities, _including_ the `findPlayerBy` functions.  
By default, the rate limit is **20 per second** with a burst limit of up to 10 per tick.

**If you exceed either, your find results will come back empty until you're under the limit again!**

`findCanQuery()` will return if you can currently query at least once, and `findCount()` will tell you how many queries you have left.  
`findMax()` and `findUpdateRate()` will get you the burst limit and regeneration interval (time in seconds to regenerate by one) respectively.


# Usage

Pretty much all remaining find functions can be divided into 4 groups and only work correctly when used in order:

1. If applicable, define your [find filters](#find-filters).
2. Make **one** [query](#find-queries)
3. If you want, [clip the results](#3-clipping) and/or `sortByDistance` (and you can do this **as often** as you want!)
4. [Retrieve the results](#4-results) (else it was all for nothing, right?)
5. You **may** now go back to *any* previous point and continue again from there. Black/whitelist and last results are stored until you change them again (or reset the E2).

## Find Filters
These are what I always see people (including myself) get wrong the most often. &nbsp;And I don't blame them either, the find blacklist & whitelist are rather poorly documented in the e2helper.

- `findInclude` functions add stuff to the whitelist
- `findDisallow` functions block things that would otherwise pass due to the whitelist
- `findExclude` functions add stuff to the blacklist
- `findAllow` functions allow things that would otherwise be blocked by the blacklist

These "prefixes" can be combined with the following filter types for a wide variety of use-cases:
|Filter | Input | Info |
|:-|:-|:-|
|`class` | string | Uses Lua patterns, see note below |
|`model` | string | Uses Lua patterns, see note below |
|`entity` | entity | |
|`entities` | array (of entities) | same list as Entity |
|`playerProps` | entity (player) | props owned by that player|

> [!Note]
> Class and Model filters will use Lua's `string.match` (which uses [patterns](https://www.lua.org/pil/20.2.html)) to check if the class/model matches.  
> This means that if you put just "prop", it will match as long as "prop" *anywhere* in the class/model. See the examples below for some common usecases.  

### Example

```
findIncludeClass("prop") # All entites whose class contains "prop", ie "prop_physics" or "prop_vehicle"
findIncludeClass("^prop_physics$") # Matching exactly "prop_physics", ie not "prop_physics_entity" 
findIncludeClass("^gmod_wire_[eh]") # Class begins with "gmod_wire_e" or "gmod_wire_h" (Using lua patterns)
findIncludeEntity(entity():isWeldedTo()) # Entity the E2 is placed on
findIncludePlayerProps(owner()) # All props owned by E2 owner
```
This whitelist will allow any entities that fit **ANY** (but at least one) of the above filters, so all your things, the entity the E2 is placed on as well as any entities which fit one of the class filters.  The blacklist works in a similar way.

### Filter Flowchart

<p align="center">
  <img src="https://github.com/user-attachments/assets/f2cbdab8-afb0-4866-a132-313c6c4a18e6" width="600" alt="Expression 2 Find Flowchart">
</p>

## Find Queries

These are the functions that actually prompt the engine to look for entities.  These all count towards the [find quota](#rate-limits).

These functions return the **number of entities found**. &nbsp;See [below](#4-results) for retrieving the actual entities.

| Function | Parameters | Explaination | Lua backend|
|-:|:-|:-|-:|
|findByName|string Name | finds all entites with the given name | [ents.FindByName](https://wiki.facepunch.com/gmod/ents.FindByName)
|findByModel|string Model | finds all entites with the given model, supports `*` wildcards | [ents.FindByModel](https://wiki.facepunch.com/gmod/ents.FindByModel)
|findByClass|string Class | finds all entites with the given class, supports `*` wildcards | [ents.FindByClass](https://wiki.facepunch.com/gmod/ents.FindByClass)
|findInSphere|vector Center, number Radius| finds all entities with the radius around the center | [ents.findInSphere](https://wiki.facepunch.com/gmod/ents.FindInSphere)
|findInBox|vector min, vector max| finds all entities inside the world-axis aligned box (`min <= pos <= max` for X, Y and Z) | [ents.findInBox](https://wiki.facepunch.com/gmod/ents.FindInBox)
|findInCone|vector tip, vector direction, number length, number degree | See below | custom implementation

> [!Important]
> findByModel and findByClass do NOT use Lua patterns, unlike their filter counterparts.

`findInCone` is a complicated one, it finds all entities which are within a certain angle from the direction and within the length.  
It is much easier to just show an example usecase:

`findInCone( Player:shootPos(), Player:eye(), 1000, 10)` will find all props that are within a 10 degrees circle of the players crosshair direction and within 1000 units.

See the [wiremod source](https://github.com/wiremod/wire/blob/master/lua/entities/gmod_wire_expression2/core/find.lua#L381-L404) for more info.

Note that the E2 will never find itself or certain "weird" entities from the [hardcoded blacklist](https://github.com/wiremod/wire/blob/master/lua/entities/gmod_wire_expression2/core/find.lua#L46), like spawnpoints or the physgun beam.

## Clipping

After a find operation the results are stored internally, and can efficiently be filtered by lua using the `findClipFrom*` (to exclude something) and `findClipTo*` (to exclude everything else).  
You won't need these for most things, so feel free to skip this section.

These function will return the remaining number of entities after filtering. You can use **any filters** from the whitelist and blacklist and some **additional** ones:

`findClipTo/FromName(string Name)` to filter the name. Just like the whitelist and blacklist filters for class and model you can also use partial strings or patterns here.

`findClipTo/FromSphere(vector Center, number Radius)` to only allow entities inside or outside the defined sphere.

`findClipTo/FromBox(vector Min, vector Max)` to only allow entities inside or outside the defined box.

`findClipToRegion(vector Origin, vector Normal)` to only allow entities on one side of a plane defined by origin and normal.  
Internally it checks if the direction from `Origin` to the entity is within 90 degrees of the `Normal`, or - for the math fans - `(entpos-origin):normalized():dot(normal) > 0`.  
Note that there is no `findClipFromRegion`, as you just have to negate the direction vector to get the opposite side of the plane.
Again a practical example: `(Player:shootPos(), vec(0,0,1))` would mean everything "above" (but **not just** straight above) the players eye position.  

## Results

`findSortByDistance(vector position)` doesn't strictly fit in this phase, but it is quite useful. It will sort all entities in the result list by their distance from the given position from near to far and also return the number of entities in the list.

You can get the results from a find operation in a few different ways, depending on what you need:

`find()` will get you the first entity from the top of the list, and `findResult(N)` will give you the N-th entity.

`findClosest(vector position)` will get you the entity that is closest to the position.

`findToArray()` and `findToTable()` allow you to retrieve the full result list, either as array or in the numeric part of a table.

You can call as many functions to retrieve results as you want, and even refine the results furthing by clipping or sorting. This will not count against the find quota, so sometimes find operations can be "saved" by smart usage of clipping.

# Examples

Find entities in a box
```golo
if (first()) {  # only run the following code on chip spawn, as it creates holos
  local Size = 1000  # Corner distance from chip. This is half the length of the created cube

  local Chip = entity()
  local MinCorner = Chip:pos() - vec(Size)  # note that findInBox is always axis aligned and the second vector must be greater in all axis
  local MaxCorner = Chip:pos() + vec(Size)

  holoCreate(1, MinCorner, vec(1 + Size*0.0015))
  holoCreate(2, MaxCorner, vec(1 + Size*0.0015))

  findExcludeEntity(Chip) # Blacklist the chip from being found
  findExcludeClass("gmod_wire_hologram") # Blacklist any entities with the class 'gmod_wire_hologram'

  local NumInBox = findInBox(MinCorner, MaxCorner)  # do the actual find operation, get number of results
  findSortByDistance(Chip:pos())  # sort results by distance
  local Results = findToArray()  # export the (now sorted) results to an array

  print(format("Found %u entities in the box! Closest one is a %s", NumInBox, Results[1,entity]:type()))
}
```
