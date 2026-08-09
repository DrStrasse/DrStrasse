[Jump to table of contents](#default-extensions)

# Egpfunctions

### ![WireLink](Type-WireLink.png "WireLink"):egpSaveFrame(![String](Type-String.png "String") Index)

Saves the frame under specified name (15 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpSaveFrame(![Number](Type-Number.png "Number") Index)

Saves the frame under specified index (15 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpLoadFrame(![String](Type-String.png "String") Index)

Loads the frame with specified name (15 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpLoadFrame(![Number](Type-Number.png "Number") Index)

Loads the frame with specified index (15 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpOrder(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Order)

Sets the order at which the object will be rendered (15 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpOrder(![Number](Type-Number.png "Number") Index)

 (15 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpOrderAbove(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Abovethis)

Makes the object render above the object at the index (15 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpOrderBelow(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Belowthis)

Makes the object render below the object at the index (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpBox(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Pos, ![Vector2](Type-Vector2.png "Vector2") Size)

Creates a box. First 2D vector is the position, second is size (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpBoxOutline(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Pos, ![Vector2](Type-Vector2.png "Vector2") Size)

Creates an outline box. First 2D vector is the position, second is size (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpRoundedBox(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Pos, ![Vector2](Type-Vector2.png "Vector2") Size)

Creates a rounded box. First 2D vector is the position, second is size (15 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpRadius(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Radius)

Changes the corner radius of the rounded box object (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpRoundedBoxOutline(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Pos, ![Vector2](Type-Vector2.png "Vector2") Size)

Creates a rounded outline box. First 2D vector is the position, second is size (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpText(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Text, ![Vector2](Type-Vector2.png "Vector2") Pos)

Creates a text object (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpTextLayout(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Text, ![Vector2](Type-Vector2.png "Vector2") Pos, ![Vector2](Type-Vector2.png "Vector2") Size)

Creates a text layout object (15 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpSetText(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Text)

Changes the text of the text object (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpAlign(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Halign)

Changes the horizontal alignment. Works on: text and text layout. Number can be 0, 1 or 2 (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpAlign(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Halign, ![Number](Type-Number.png "Number") Valign)

Changes the horizontal and vertical alignment. Works on: text and text layout. Numbers can be 0, 1 or 2 (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpFiltering(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Filtering)

Changes the texture filter used to draw the object. Works on objects that draw a material. See _TEXFILTER constants (POINT=sharp, ANISOTROPIC=blurry/default) (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpGlobalFiltering(![Number](Type-Number.png "Number") Filtering)

Changes the texture filter used to draw all EGP Objects. Works only on EGP Screens. See _TEXFILTER constants (POINT=sharp, ANISOTROPIC=blurry/default) (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpFont(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Font)

 (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpFont(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Font, ![Number](Type-Number.png "Number") Size)

Changes the font and size of the text object (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpPoly(![Number](Type-Number.png "Number") Index, ...)

Creates a polygon with specified points as 2D/4D vectors (x,y)/(x,y,u,v) (20 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpPoly(![Number](Type-Number.png "Number") Index, ![Array](Type-Array.png "Array") Args)

Creates a polygon with specified points as array of 2D/4D vectors (x,y)/(x,y,u,v) (20 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpPolyOutline(![Number](Type-Number.png "Number") Index, ...)

Creates a outline polygon with specified points as 2D/4D vectors (x,y)/(x,y,u,v) (20 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpPolyOutline(![Number](Type-Number.png "Number") Index, ![Array](Type-Array.png "Array") Args)

Creates a outline polygon with specified points as array of 2D/4D vectors (x,y)/(x,y,u,v) (20 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpAddVertices(![Number](Type-Number.png "Number") Index, ![Array](Type-Array.png "Array") Args)

 (20 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpLineStrip(![Number](Type-Number.png "Number") Index, ...)

Creates a curve with specified points as 2D/4D vectors (x,y)/(x,y,u,v) (20 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpLineStrip(![Number](Type-Number.png "Number") Index, ![Array](Type-Array.png "Array") Args)

Creates a curve with specified points as array of 2D/4D vectors (x,y)/(x,y,u,v) (20 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpLine(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Pos1, ![Vector2](Type-Vector2.png "Vector2") Pos2)

Creates a line. First 2D vector is the start position, second is end position (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpCircle(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Pos, ![Vector2](Type-Vector2.png "Vector2") Size)

Creates a circle. First 2D vector is the position, second is size (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpCircleOutline(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Pos, ![Vector2](Type-Vector2.png "Vector2") Size)

Creates an outline circle. First 2D vector is the position, second is size (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpTriangle(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") V1, ![Vector2](Type-Vector2.png "Vector2") V2, ![Vector2](Type-Vector2.png "Vector2") V3)

Creates a triangle with specified vertices (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpTriangleOutline(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") V1, ![Vector2](Type-Vector2.png "Vector2") V2, ![Vector2](Type-Vector2.png "Vector2") V3)

Creates a outline triangle with specified vertices (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpWedge(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Pos, ![Vector2](Type-Vector2.png "Vector2") Size)

Creates a wedge object. Wedge objects are like circles, except they have a cake-piece-like mouth which you can change using egpSize (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpWedgeOutline(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Pos, ![Vector2](Type-Vector2.png "Vector2") Size)

Creates a outline wedge object. Wedge objects are like circles, except they have a cake-piece-like mouth which you can change using egpSize (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egp3DTracker(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Pos)

Creates a 3D tracker object at specified world position (15 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egp3DTracker(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Pos, ![Number](Type-Number.png "Number") Directionality)

Creates a 3D tracker object at specified world position that is only visible behind (directionality=-1), in front of (directionality=1) the screen/emitter, or both (directionality=0). HUD is unaffected by directionality. (15 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpPos(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Pos)

Changes the world position of the 3D tracker object (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpSize(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Size)

 (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpSize(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Size)

Changes the size of the text/line/outline object (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpPos(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Pos)

 (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpAngle(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Angle)

Changes the angle of the object (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpAngle(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Worldpos, ![Vector2](Type-Vector2.png "Vector2") Axispos, ![Number](Type-Number.png "Number") Angle)

Rotates the object around the first vec2 with the second vec2 as offset at angle N (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpColor(![Number](Type-Number.png "Number") Index, ![Vector4](Type-Vector4.png "Vector4") Color)

Changes the color and alpha of the object (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpColor(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Color)

Changes the color of the object (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpColor(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") R, ![Number](Type-Number.png "Number") G, ![Number](Type-Number.png "Number") B, ![Number](Type-Number.png "Number") A)

Changes the color and alpha of the object (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpAlpha(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") A)

Changes the alpha (transparency) of an object (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpMaterial(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Material)

Changes the material of the object (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpMaterialFromScreen(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Gpu)

Sets the material of the object to a current snapshot of the target screen. Note that this only works for players which see both the egp as well the target screen at that time (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpFidelity(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Fidelity)

Changes the fidelity of the object (the number of vertices the circle will use) (10 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpFidelity(![Number](Type-Number.png "Number") Index)

 (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpParent(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Parentindex)

Parents the object to another object. Parented objects' positions are local to their parent (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpParent(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Parent)

Parents the 3D tracker object to an entity (10 ops)

### ![Entity](Type-Entity.png "Entity") = ![WireLink](Type-WireLink.png "WireLink"):egpTrackerParent(![Number](Type-Number.png "Number") Index)

 (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpParentToCursor(![Number](Type-Number.png "Number") Index)

Parents the object to player's cursor (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpUnParent(![Number](Type-Number.png "Number") Index)

Un-parents the object (10 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpParent(![Number](Type-Number.png "Number") Index)

 (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpClear()

Clears the EGP screen (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpRemove(![Number](Type-Number.png "Number") Index)

 (10 ops)

### ![Vector2](Type-Vector2.png "Vector2") = ![WireLink](Type-WireLink.png "WireLink"):egpPos(![Number](Type-Number.png "Number") Index)

Returns the position of the object (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![WireLink](Type-WireLink.png "WireLink"):egpGlobalPos(![Number](Type-Number.png "Number") Index)

 (20 ops)

### ![Array](Type-Array.png "Array") = ![WireLink](Type-WireLink.png "WireLink"):egpGlobalVertices(![Number](Type-Number.png "Number") Index)

 (20 ops)

### ![Vector2](Type-Vector2.png "Vector2") = ![WireLink](Type-WireLink.png "WireLink"):egpSize(![Number](Type-Number.png "Number") Index)

Returns the size of the object (5 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpSizeNum(![Number](Type-Number.png "Number") Index)

 (5 ops)

### ![Vector4](Type-Vector4.png "Vector4") = ![WireLink](Type-WireLink.png "WireLink"):egpColor4(![Number](Type-Number.png "Number") Index)

 (5 ops)

### ![Vector](Type-Vector.png "Vector") = ![WireLink](Type-WireLink.png "WireLink"):egpColor(![Number](Type-Number.png "Number") Index)

 (5 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpAlpha(![Number](Type-Number.png "Number") Index)

 (5 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpAngle(![Number](Type-Number.png "Number") Index)

 (5 ops)

### ![String](Type-String.png "String") = ![WireLink](Type-WireLink.png "WireLink"):egpMaterial(![Number](Type-Number.png "Number") Index)

 (5 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpRadius(![Number](Type-Number.png "Number") Index)

 (5 ops)

### ![Array](Type-Array.png "Array") = ![WireLink](Type-WireLink.png "WireLink"):egpVertices(![Number](Type-Number.png "Number") Index)

 (10 ops)

### ![Array](Type-Array.png "Array") = ![WireLink](Type-WireLink.png "WireLink"):egpObjectIndexes()

Returns an array containing all object indexes being used (1 ops)

### ![Array](Type-Array.png "Array") = ![WireLink](Type-WireLink.png "WireLink"):egpObjectTypes()

Returns an array whose keys are bound to object index, and value being the type of particular object (1 ops)

### ![String](Type-String.png "String") = ![WireLink](Type-WireLink.png "WireLink"):egpObjectType(![Number](Type-Number.png "Number") Index)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpCopy(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Fromindex)

 (15 ops)

### ![Vector2](Type-Vector2.png "Vector2") = ![WireLink](Type-WireLink.png "WireLink"):egpCursor(![Entity](Type-Entity.png "Entity") Ply)

Returns the specified player's aim position on the screen (20 ops)

### ![Vector2](Type-Vector2.png "Vector2") = egpScrSize(![Entity](Type-Entity.png "Entity") Ply)

Returns the player's screen resolution size (10 ops)

### ![Number](Type-Number.png "Number") = egpScrW(![Entity](Type-Entity.png "Entity") Ply)

Returns the player's screen resolution width (10 ops)

### ![Number](Type-Number.png "Number") = egpScrH(![Entity](Type-Entity.png "Entity") Ply)

Returns the player's screen resolution height (10 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpHasObject(![Number](Type-Number.png "Number") Index)

Returns 1 if the object with specified index exists on the screen, 0 if not (15 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpObjectContainsPoint(![Number](Type-Number.png "Number") Index, ![Vector2](Type-Vector2.png "Vector2") Point)

Returns 1 if the object with specified index contains the specified point (20 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpScale(![Vector2](Type-Vector2.png "Vector2") Xscale, ![Vector2](Type-Vector2.png "Vector2") Yscale)

Sets the scale of the screen's X axis to the first vector and Y axis to the second vector (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpResolution(![Vector2](Type-Vector2.png "Vector2") Topleft, ![Vector2](Type-Vector2.png "Vector2") Bottomright)

Sets the scale of the screen such that the top left corner is equal to the first vector and the bottom right corner is equal to the second vector (10 ops)

### ![Vector2](Type-Vector2.png "Vector2") = ![WireLink](Type-WireLink.png "WireLink"):egpOrigin()

 (10 ops)

### ![Vector2](Type-Vector2.png "Vector2") = ![WireLink](Type-WireLink.png "WireLink"):egpSize()

 (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpDrawTopLeft(![Number](Type-Number.png "Number") Onoff)

Set to 1 to make boxes, outline boxes, rounded boxes, and rounded outline boxes draw from the top left corner instead of from the center (10 ops)

### ![Vector](Type-Vector.png "Vector") = ![WireLink](Type-WireLink.png "WireLink"):egpToWorld(![Vector2](Type-Vector2.png "Vector2") Pos)

Converts a 2D vector on the screen or emitter into a 3D vector in the world (20 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpHudToggle()

Toggles the HUD on/off (25 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpHudEnable(![Number](Type-Number.png "Number") Enable)

Enables the HUD if the input is not 0 (25 ops)

### ![Array](Type-Array.png "Array") = ![WireLink](Type-WireLink.png "WireLink"):egpConnectedUsers()

Returns an array of players connected to the EGP (25 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpNumObjects()

Returns the number of objects on the screen (10 ops)

### ![Number](Type-Number.png "Number") = egpMaxObjects()

Returns the maximum amount of objects you can have (10 ops)

### ![Number](Type-Number.png "Number") = egpMaxUmsgPerSecond()

Returns the maximum number of usermessages you can send per second (10 ops)

### ![Number](Type-Number.png "Number") = egpBytesLeft()

 (10 ops)

### ![Number](Type-Number.png "Number") = egpCanSendUmsg()

Returns 1 if you can send an usermessage at the moment, 0 otherwise (5 ops)

### ![Number](Type-Number.png "Number") = egpClearQueue()

Clears your entire queue (5 ops)

### ![Number](Type-Number.png "Number") = egpQueue()

Returns the number of items in your queue (10 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpRunOnQueue(![Number](Type-Number.png "Number") Yesno)

Set to 1 if you want your E2 to be triggered once the queue has finished sending all items in the queue for the screen (10 ops)

### ![Number](Type-Number.png "Number") = egpQueueClk()

Returns 1 if the current execution was caused by the EGP queue system (10 ops)

### ![Number](Type-Number.png "Number") = egpQueueClk(![WireLink](Type-WireLink.png "WireLink") Screen)

Returns 1 if the current execution was caused by the EGP queue system of specified screen (10 ops)

### ![Number](Type-Number.png "Number") = egpQueueClk(![Entity](Type-Entity.png "Entity") Screen)

Returns 1 if the current execution was caused by the EGP queue system of specified screen (10 ops)

### ![Entity](Type-Entity.png "Entity") = egpQueueScreen()

Returns the screen entity which the queue finished sending items for (10 ops)

### ![WireLink](Type-WireLink.png "WireLink") = egpQueueScreenWirelink()

Returns the screen wirelink which the queue finished sending items for (10 ops)

### ![Entity](Type-Entity.png "Entity") = egpQueuePlayer()

Returns the player which ordered the items to be sent (10 ops)

### ![Number](Type-Number.png "Number") = egpQueueClkPly(![Entity](Type-Entity.png "Entity") Ply)

Returns 1 if the current execution was caused by the EGP queue system, and the player E was the player who ordered the items to be sent (10 ops)
