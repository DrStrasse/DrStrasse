[Jump to table of contents](#default-extensions)

# Find

### ![Number](Type-Number.png "Number") = findUpdateRate()

Returns the minimum delay between entity find events on a chip (2 ops)

### ![Number](Type-Number.png "Number") = findMax()

Returns the maximum number of finds per E2 (2 ops)

### ![Number](Type-Number.png "Number") = findCount()

Returns the remaining available find calls (2 ops)

### ![Number](Type-Number.png "Number") = findCanQuery()

Returns 1 if find functions can be used, 0 otherwise (2 ops)

### ![Number](Type-Number.png "Number") = findInSphere(![Vector](Type-Vector.png "Vector") Center, ![Number](Type-Number.png "Number") Radius)

Finds entities in a sphere around V with a radius of N, returns the number found after filtering (30 ops)

### ![Number](Type-Number.png "Number") = findInCone(![Vector](Type-Vector.png "Vector") Position, ![Vector](Type-Vector.png "Vector") Direction, ![Number](Type-Number.png "Number") Length, ![Number](Type-Number.png "Number") Degrees)

Like findInSphere but with a http://mathworld.wolfram.com/SphericalCone.html Spherical cone, arguments are for position, direction, length, and degrees (works now) (30 ops)

### ![Number](Type-Number.png "Number") = findInBox(![Vector](Type-Vector.png "Vector") Min, ![Vector](Type-Vector.png "Vector") Max)

Like findInSphere but with a globally aligned box, the arguments are the diagonal corners of the box (30 ops)

### ![Number](Type-Number.png "Number") = findByName(![String](Type-String.png "String") Name)

Find all entities with the given name (30 ops)

### ![Number](Type-Number.png "Number") = findByModel(![String](Type-String.png "String") Model)

Find all entities with the given model (30 ops)

### ![Number](Type-Number.png "Number") = findByClass(![String](Type-String.png "String") Class)

Find all entities with the given class (30 ops)

### ![Entity](Type-Entity.png "Entity") = findPlayerByName(![String](Type-String.png "String") Name)

Returns the player with the given name, this is an exception to the rule (30 ops)

### ![Entity](Type-Entity.png "Entity") = findPlayerBySteamID(![String](Type-String.png "String") Id)

Returns the player with the given SteamID32 (30 ops)

### ![Entity](Type-Entity.png "Entity") = findPlayerBySteamID64(![String](Type-String.png "String") Id)

Returns the player with the given SteamID64 (30 ops)

### findExcludeEntities(![Array](Type-Array.png "Array") Arr)

Exclude all entities in array from future finds (10 ops)

### findExcludePlayer(![Entity](Type-Entity.png "Entity") Ent)

Exclude specified player from future finds (put it on the entity blacklist) (10 ops)

### findExcludeEntity(![Entity](Type-Entity.png "Entity") Ent)

Exclude entity from future finds (10 ops)

### findExcludePlayer(![String](Type-String.png "String") Name)

Exclude player with specified name from future finds (put it on the entity blacklist) (10 ops)

### findExcludePlayerProps(![Entity](Type-Entity.png "Entity") Ply)

Exclude entities owned by specified player from future finds (10 ops)

### findExcludePlayerProps(![String](Type-String.png "String") Name)

Exclude entities owned by player with specified name from future finds (10 ops)

### findExcludeModel(![String](Type-String.png "String") Model)

Exclude entities with this model (or partial model name) from future finds (10 ops)

### findExcludeClass(![String](Type-String.png "String") Class)

Exclude entities with this class (or partial class name) from future finds (10 ops)

### findAllowEntities(![Array](Type-Array.png "Array") Arr)

Remove all entities in array from the blacklist (10 ops)

### findAllowEntity(![Entity](Type-Entity.png "Entity") Ent)

Remove entity from the blacklist (10 ops)

### findAllowPlayer(![Entity](Type-Entity.png "Entity") Ent)

Remove specified player from the entity blacklist (10 ops)

### findAllowPlayer(![String](Type-String.png "String") Name)

Remove player with specified name from the entity blacklist (10 ops)

### findAllowPlayerProps(![Entity](Type-Entity.png "Entity") Ply)

Remove entities owned by specified player from the blacklist (10 ops)

### findAllowPlayerProps(![String](Type-String.png "String") Name)

Remove entities owned by player with specified name from the blacklist (10 ops)

### findAllowModel(![String](Type-String.png "String") Model)

Remove entities with this model (or partial model name) from the blacklist (10 ops)

### findAllowClass(![String](Type-String.png "String") Class)

Remove entities with this class (or partial class name) from the blacklist (10 ops)

### findIncludeEntities(![Array](Type-Array.png "Array") Arr)

Include all entities in array in future finds, and remove others not in the whitelist (10 ops)

### findIncludeEntity(![Entity](Type-Entity.png "Entity") Ent)

Include entity in future finds, and remove others not in the whitelist (10 ops)

### findIncludePlayer(![Entity](Type-Entity.png "Entity") Ent)

Include specified player in future finds, and remove other entities not in the entity whitelist (10 ops)

### findIncludePlayer(![String](Type-String.png "String") Name)

Include player with specified name in future finds, and remove other entities not in the entity whitelist (10 ops)

### findIncludePlayerProps(![Entity](Type-Entity.png "Entity") Ply)

Include entities owned by specified player in future finds, and remove others not in the whitelist (10 ops)

### findIncludePlayerProps(![String](Type-String.png "String") Name)

Include entities owned by player with specified name in future finds, and remove others not in the whitelist (10 ops)

### findIncludeModel(![String](Type-String.png "String") Model)

Include entities with this model (or partial model name) in future finds, and remove others not in the whitelist (10 ops)

### findIncludeClass(![String](Type-String.png "String") Class)

Include entities with this class (or partial class name) in future finds, and remove others not in the whitelist (10 ops)

### findDisallowEntities(![Array](Type-Array.png "Array") Arr)

Remove all entities in array from the whitelist (10 ops)

### findDisallowPlayer(![Entity](Type-Entity.png "Entity") Ent)

Remove specified player from the entity whitelist (10 ops)

### findDisallowEntity(![Entity](Type-Entity.png "Entity") Ent)

Remove entity from the whitelist (10 ops)

### findDisallowPlayer(![String](Type-String.png "String") Name)

Remove player with specified name from the entity whitelist (10 ops)

### findDisallowPlayerProps(![Entity](Type-Entity.png "Entity") Ply)

Remove entities owned by specified player from the whitelist (10 ops)

### findDisallowPlayerProps(![String](Type-String.png "String") Name)

Remove entities owned by player with specified name from the whitelist (10 ops)

### findDisallowModel(![String](Type-String.png "String") Model)

Remove entities with this model (or partial model name) from the whitelist (10 ops)

### findDisallowClass(![String](Type-String.png "String") Class)

Remove entities with this class (or partial class name) from the whitelist (10 ops)

### findClearBlackList()

Clear all entries from the entire blacklist (10 ops)

### findClearBlackEntityList()

Clear all entries from the entity blacklist (10 ops)

### findClearBlackPlayerPropList()

Clear all entries from the prop owner blacklist (10 ops)

### findClearBlackModelList()

Clear all entries from the model blacklist (10 ops)

### findClearBlackClassList()

Clear all entries from the class blacklist (10 ops)

### findClearWhiteList()

Clear all entries from the entire whitelist (10 ops)

### findClearWhiteEntityList()

Clear all entries from the player whitelist (10 ops)

### findClearWhitePlayerPropList()

Clear all entries from the prop owner whitelist (10 ops)

### findClearWhiteModelList()

Clear all entries from the model whitelist (10 ops)

### findClearWhiteClassList()

Clear all entries from the class whitelist (10 ops)

### findAllowBlockedClasses(![Number](Type-Number.png "Number") Usehardcodedfilter)

Allows or disallows finding entities on the hardcoded class blocklist, including classes like "prop_dynamic", "physgun_beam" and "gmod_ghost". (2 ops)

### ![Entity](Type-Entity.png "Entity") = findResult(![Number](Type-Number.png "Number") Index)

Returns the indexed entity from the previous find event (valid parameters are 1 to the number of entities found) (2 ops)

### ![Entity](Type-Entity.png "Entity") = findClosest(![Vector](Type-Vector.png "Vector") Position)

Returns the closest entity to the given point from the previous find event (2 ops)

### ![Array](Type-Array.png "Array") = findToArray()

Formats the query as an array, R[Index,entity] to get an entity (2 ops)

### ![Entity](Type-Entity.png "Entity") = find()

Equivalent to findResult(1) (2 ops)

### ![Number](Type-Number.png "Number") = findSortByDistance(![Vector](Type-Vector.png "Vector") Position)

Sorts the entities from the last find event, index 1 is the closest to point V, returns the number of entities in the list (10 ops)

### ![Number](Type-Number.png "Number") = findClipToClass(![String](Type-String.png "String") Class)

Filters the list of entities by removing all entities that are NOT of this class (5 ops)

### ![Number](Type-Number.png "Number") = findClipFromClass(![String](Type-String.png "String") Class)

Filters the list of entities by removing all entities that are of this class (5 ops)

### ![Number](Type-Number.png "Number") = findClipToModel(![String](Type-String.png "String") Model)

Filters the list of entities by removing all entities that do NOT have this model (5 ops)

### ![Number](Type-Number.png "Number") = findClipFromModel(![String](Type-String.png "String") Model)

Filters the list of entities by removing all entities that do have this model (5 ops)

### ![Number](Type-Number.png "Number") = findClipToName(![String](Type-String.png "String") Name)

Filters the list of entities by removing all entities that do NOT have this name (5 ops)

### ![Number](Type-Number.png "Number") = findClipFromName(![String](Type-String.png "String") Name)

Filters the list of entities by removing all entities that do have this name (5 ops)

### ![Number](Type-Number.png "Number") = findClipToSphere(![Vector](Type-Vector.png "Vector") Center, ![Number](Type-Number.png "Number") Radius)

Filters the list of entities by removing all entities NOT within the specified sphere (center, radius) (5 ops)

### ![Number](Type-Number.png "Number") = findClipFromSphere(![Vector](Type-Vector.png "Vector") Center, ![Number](Type-Number.png "Number") Radius)

Filters the list of entities by removing all entities within the specified sphere (center, radius) (5 ops)

### ![Number](Type-Number.png "Number") = findClipToRegion(![Vector](Type-Vector.png "Vector") Origin, ![Vector](Type-Vector.png "Vector") Perpendicular)

Filters the list of entities by removing all entities NOT on the positive side of the defined plane. (Plane origin, vector perpendicular to the plane) You can define any convex hull using this (5 ops)

### ![Number](Type-Number.png "Number") = findClipFromBox(![Vector](Type-Vector.png "Vector") Min, ![Vector](Type-Vector.png "Vector") Max)

Filters the list of entities by removing all entities within the specified box (5 ops)

### ![Number](Type-Number.png "Number") = findClipToBox(![Vector](Type-Vector.png "Vector") Min, ![Vector](Type-Vector.png "Vector") Max)

Filters the list of entities by removing all entities NOT within the specified box (5 ops)

### ![Number](Type-Number.png "Number") = findClipFromEntity(![Entity](Type-Entity.png "Entity") Ent)

Filters the list of entities by removing this entity (5 ops)

### ![Number](Type-Number.png "Number") = findClipFromEntities(![Array](Type-Array.png "Array") Entities)

Filters the list of entities by removing all entities that are in this array (5 ops)

### ![Number](Type-Number.png "Number") = findClipToEntity(![Entity](Type-Entity.png "Entity") Ent)

Filters the list of entities by removing all except this entity (5 ops)

### ![Number](Type-Number.png "Number") = findClipToEntities(![Array](Type-Array.png "Array") Entities)

Filters the list of entities by removing all entities that are NOT in this array (5 ops)

### ![Number](Type-Number.png "Number") = findClipToPlayerProps(![Entity](Type-Entity.png "Entity") Ply)

 (5 ops)

### ![Number](Type-Number.png "Number") = findClipFromPlayerProps(![Entity](Type-Entity.png "Entity") Ply)

 (5 ops)
