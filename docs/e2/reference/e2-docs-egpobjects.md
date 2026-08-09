[Jump to table of contents](#default-extensions)

# Egpobjects

### Egpobject = Egpobject:modify(![Table](Type-Table.png "Table") Arguments)

Modifies an object with the provided arguments. (10 ops)

### Egpobject:setOrder(![Number](Type-Number.png "Number") Order)

Sets the order at which the object will be rendered. This is different from index (15 ops)

### ![Number](Type-Number.png "Number") = Egpobject:getOrder()

Returns the order at which the object is rendered (15 ops)

### Egpobject:setOrderAbove(Egpobject Abovethis)

Makes the object render above the object (15 ops)

### Egpobject:setOrderBelow(Egpobject Belowthis)

Makes the object render below the object (15 ops)

### Egpobject:setText(![String](Type-String.png "String") Text)

Changes the text of the text object (7 ops)

### Egpobject:setText(![String](Type-String.png "String") Text, ![String](Type-String.png "String") Font, ![Number](Type-Number.png "Number") Size)

Changes the text, font, and text size of the text object (7 ops)

### Egpobject:setAlign(![Number](Type-Number.png "Number") Halign)

Changes the horizontal alignment. Works on: text and text layout. Number can be 0, 1 or 2 (7 ops)

### Egpobject:setAlign(![Number](Type-Number.png "Number") Halign, ![Number](Type-Number.png "Number") Valign)

Changes the horizontal and vertical alignment. Works on: text and text layout. Numbers can be 0, 1 or 2 (7 ops)

### Egpobject:setFiltering(![Number](Type-Number.png "Number") Filtering)

Changes the texture filter used to draw the object. Works on objects that draw a material. See _TEXFILTER constants (POINT=sharp, ANISOTROPIC=blurry/default) (7 ops)

### Egpobject:setFont(![String](Type-String.png "String") Font)

Changes the font of the text object (7 ops)

### Egpobject:setFont(![String](Type-String.png "String") Font, ![Number](Type-Number.png "Number") Size)

Changes the font and size of the text object (7 ops)

### Egpobject:setPos(![Vector](Type-Vector.png "Vector") Pos)

Changes the world position of the 3D tracker object (10 ops)

### Egpobject:setSize(![Vector2](Type-Vector2.png "Vector2") Size)

Changes the width and height of an object (7 ops)

### Egpobject:setSize(![Number](Type-Number.png "Number") Width, ![Number](Type-Number.png "Number") Height)

Changes the width and height of an object (7 ops)

### Egpobject:setSize(![Number](Type-Number.png "Number") Size)

Changes the size of the text/line/outline object (7 ops)

### Egpobject:setPos(![Vector2](Type-Vector2.png "Vector2") Pos)

Changes the position of the object (7 ops)

### Egpobject:setPos(![Number](Type-Number.png "Number") X, ![Number](Type-Number.png "Number") Y)

Changes the position of the object (7 ops)

### Egpobject:setPos(![Number](Type-Number.png "Number") X, ![Number](Type-Number.png "Number") Y, ![Number](Type-Number.png "Number") X2, ![Number](Type-Number.png "Number") Y2)

Changes the position of the start and end of a line object, otherwise acts normally. (7 ops)

### Egpobject:setAngle(![Number](Type-Number.png "Number") Angle)

Changes the angle of the object (7 ops)

### Egpobject:setPos(![Number](Type-Number.png "Number") X, ![Number](Type-Number.png "Number") Y, ![Number](Type-Number.png "Number") Angle)

Changes the position and angle of the object (7 ops)

### Egpobject:rotateAroundAxis(![Vector2](Type-Vector2.png "Vector2") Worldpos, ![Vector2](Type-Vector2.png "Vector2") Axispos, ![Number](Type-Number.png "Number") Angle)

Rotates the object around the first vec2 with the second vec2 as offset at angle N (7 ops)

### Egpobject:setVertices(![Array](Type-Array.png "Array") Verts)

 (7 ops)

### Egpobject:setVertices(...)

 (7 ops)

### Egpobject:setColor(![Vector4](Type-Vector4.png "Vector4") Color)

Changes the color and alpha of the object (7 ops)

### Egpobject:setColor(![Vector](Type-Vector.png "Vector") Color)

Changes the color of the object (7 ops)

### Egpobject:setColor(![Number](Type-Number.png "Number") R, ![Number](Type-Number.png "Number") G, ![Number](Type-Number.png "Number") B, ![Number](Type-Number.png "Number") A)

Changes the color and alpha of the object (7 ops)

### Egpobject:setAlpha(![Number](Type-Number.png "Number") A)

Changes the alpha (transparency) of an object (7 ops)

### Egpobject:setMaterial(![String](Type-String.png "String") Material)

Changes the material of the object (7 ops)

### Egpobject:setMaterialFromScreen(![Entity](Type-Entity.png "Entity") Gpu)

Sets the material of the object to a current snapshot of the target screen. Note that this only works for players which see both the egp as well the target screen at that time (7 ops)

### Egpobject:setFidelity(![Number](Type-Number.png "Number") Fidelity)

Changes the fidelity of the object (the number of vertices the circle will use) (7 ops)

### ![Number](Type-Number.png "Number") = Egpobject:getFidelity()

Returns the fidelity of the object (7 ops)

### Egpobject:parentTo(Egpobject Parent)

Parents the object to another object. Parented objects' positions are local to their parent (7 ops)

### Egpobject:parentTo(![Number](Type-Number.png "Number") Parentindex)

Parents the object to another object. Parented objects' positions are local to their parent (7 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpParent(Egpobject Child, Egpobject Parent)

Parents the object to another object. Parented objects' positions are local to their parent (7 ops)

### Egpobject:trackerParent(![Entity](Type-Entity.png "Entity") Parent)

Parents the 3D tracker object to an entity (7 ops)

### ![Entity](Type-Entity.png "Entity") = Egpobject:trackerParent()

Returns the parent entity of the 3D tracker object. (7 ops)

### Egpobject:parentToCursor()

Parents the object to player's cursor (7 ops)

### Egpobject:unparent()

Un-parents the object (7 ops)

### ![Number](Type-Number.png "Number") = Egpobject:parentIndex()

Returns the index of the parent object (7 ops)

### Egpobject = Egpobject:parent()

Returns the parent object (7 ops)

### ![WireLink](Type-WireLink.png "WireLink"):egpRemove(Egpobject Obj)

 (7 ops)

### Egpobject:remove()

Removes the object from the screen (7 ops)

### Egpobject:draw()

Shows a hidden EGP object. (7 ops)

### Egpobject:hide()

Removes an object from the screen but keeps its data intact. (7 ops)

### ![Number](Type-Number.png "Number") = Egpobject:isVisible()

Returns 1 if the object is visible. (7 ops)

### ![Vector](Type-Vector.png "Vector") = Egpobject:globalPos()

Returns the "global" (= it takes the parents' positions into consideration) position as a 3D vector. X and Y being the 2D X,Y coordinates, while Z is the angle (20 ops)

### ![Array](Type-Array.png "Array") = Egpobject:globalVertices()

Returns an array of 2D vectors with the "global" positions of the vertices in the object (20 ops)

### ![Number](Type-Number.png "Number") = ![WireLink](Type-WireLink.png "WireLink"):egpHasObject(Egpobject Object)

Returns 1 if the object exists on the screen, 0 if not (20 ops)

### ![Vector2](Type-Vector2.png "Vector2") = Egpobject:getPos()

Returns the position of the object (3 ops)

### ![Vector](Type-Vector.png "Vector") = Egpobject:getPosAng()

Returns the position (x, y) and angle (z) of the object (3 ops)

### ![Vector2](Type-Vector2.png "Vector2") = Egpobject:getSize()

Returns the size of the object (3 ops)

### ![Number](Type-Number.png "Number") = Egpobject:getSizeNum()

Returns the size of the text/line/outline object (3 ops)

### ![Vector4](Type-Vector4.png "Vector4") = Egpobject:getColor4()

Returns the color of the object as a vector4 (3 ops)

### ![Vector](Type-Vector.png "Vector") = Egpobject:getColor()

Returns the color of the object as a vector (3 ops)

### ![Number](Type-Number.png "Number") = Egpobject:getAlpha()

Returns the alpha of the object (3 ops)

### ![Number](Type-Number.png "Number") = Egpobject:getAngle()

Returns the angle of the object (3 ops)

### ![String](Type-String.png "String") = Egpobject:getMaterial()

Returns the material of the object. Note this does not return anything when using a GPU material (3 ops)

### ![Number](Type-Number.png "Number") = Egpobject:getRadius()

Returns the radius of the object (3 ops)

### ![Array](Type-Array.png "Array") = Egpobject:getVertices()

Returns an array of the vertices of the object (10 ops)

### ![String](Type-String.png "String") = Egpobject:getObjectType()

Returns the type of the object (4 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpCopy(![Number](Type-Number.png "Number") Index, Egpobject From)

 (15 ops)

### Egpobject:copyFrom(Egpobject From)

Copies the settings of the second object into the first. If the first object does not exist, it's created (15 ops)

### ![Number](Type-Number.png "Number") = Egpobject:containsPoint(![Vector2](Type-Vector2.png "Vector2") Point)

Returns 1 if the object contains the specified point (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpobject(![Number](Type-Number.png "Number") Index)

Returns the EGPObject at the index (5 ops)

### Egpobject = noegpobject()

 (1 ops)

### ![String](Type-String.png "String") = toString(Egpobject Egpo)

Returns a string representation of the EGPObject (1 ops)

### ![String](Type-String.png "String") = Egpobject:toString()

Returns a string representation of the EGPObject (1 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpTextLayout(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpLineStrip(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpCircleOutline(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpLine(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpBox(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpBoxOutline(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egp3DTracker(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpCircle(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpRoundedBoxOutline(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpPoly(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpPolyOutline(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpRoundedBox(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpWedgeOutline(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpWedge(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)

### Egpobject = ![WireLink](Type-WireLink.png "WireLink"):egpText(![Number](Type-Number.png "Number") Index, ![Table](Type-Table.png "Table") Args)

 (10 ops)
