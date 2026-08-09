[Jump to table of contents](#table-of-contents)

# Custom/tracesystem

### ![Vector](Type-Vector.png "Vector") = rayPlaneIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Vector](Type-Vector.png "Vector") Pos, ![Vector](Type-Vector.png "Vector") Normal)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = rayFaceIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Vector](Type-Vector.png "Vector") Pos, ![Vector](Type-Vector.png "Vector") Normal, ![Vector](Type-Vector.png "Vector") Size, ![Number](Type-Number.png "Number") Ang)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = rayPolygonIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Vector](Type-Vector.png "Vector") Vertex1, ![Vector](Type-Vector.png "Vector") Vertex2, ![Vector](Type-Vector.png "Vector") Vertex3)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = rayAABBoxIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Vector](Type-Vector.png "Vector") Pos, ![Vector](Type-Vector.png "Vector") Size)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = rayOBBoxIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Vector](Type-Vector.png "Vector") Pos, ![Vector](Type-Vector.png "Vector") Size, ![Angle](Type-Angle.png "Angle") Ang)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = rayCircleIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Vector](Type-Vector.png "Vector") Pos, ![Vector](Type-Vector.png "Vector") Normal, ![Number](Type-Number.png "Number") Radius)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = raySphereIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Vector](Type-Vector.png "Vector") Pos, ![Number](Type-Number.png "Number") Radius)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = rayAAEllipsoidIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Vector](Type-Vector.png "Vector") Pos, ![Vector](Type-Vector.png "Vector") Size)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = rayOEllipsoidIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Vector](Type-Vector.png "Vector") Pos, ![Vector](Type-Vector.png "Vector") Size, ![Angle](Type-Angle.png "Angle") Ang)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = coneSphereIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Vector](Type-Vector.png "Vector") Pos, ![Number](Type-Number.png "Number") Radius, ![Number](Type-Number.png "Number") Ang)

 (0 ops)

### ![Number](Type-Number.png "Number") = tsShapeCanCreate()

 (0 ops)

### tsShapeShare(![Number](Type-Number.png "Number") Share)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeCreate(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Model, ![Number](Type-Number.png "Number") Radius, ![Number](Type-Number.png "Number") Rotation, ![Vector](Type-Vector.png "Vector") Pos, ![Vector](Type-Vector.png "Vector") Normal, ![Vector](Type-Vector.png "Vector") Size, ![Angle](Type-Angle.png "Angle") Ang, ![Vector](Type-Vector.png "Vector") Vertex1, ![Vector](Type-Vector.png "Vector") Vertex2, ![Vector](Type-Vector.png "Vector") Vertex3)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeCreate(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![String](Type-String.png "String") = tsShapePolygon(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Vertex1, ![Vector](Type-Vector.png "Vector") Vertex2, ![Vector](Type-Vector.png "Vector") Vertex3)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeModel(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Model)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeRadius(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Radius)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeRotation(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Rotation)

 (0 ops)

### ![String](Type-String.png "String") = tsShapePos(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Pos)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeVertices(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Vertex1, ![Vector](Type-Vector.png "Vector") Vertex2, ![Vector](Type-Vector.png "Vector") Vertex3)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeAng(![Number](Type-Number.png "Number") Index, ![Angle](Type-Angle.png "Angle") Ang)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeNormal(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Normal)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeSize(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Size)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeParent(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Parent)

 (0 ops)

### ![String](Type-String.png "String") = tsShapeRemove(![Number](Type-Number.png "Number") Index)

 (0 ops)

### tsShapeClear()

 (0 ops)

### Tracedata = tsRayPlaneIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir)

 (0 ops)

### Tracedata = tsRayFaceIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir)

 (0 ops)

### Tracedata = tsRayPolygonIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir)

 (0 ops)

### Tracedata = tsRayBoxIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir)

 (0 ops)

### Tracedata = tsRayCircleIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir)

 (0 ops)

### Tracedata = tsRaySphereIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir)

 (0 ops)

### Tracedata = tsRayEllipsoidIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir)

 (0 ops)

### Tracedata = tsRayIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir)

 (0 ops)

### Tracedata = tsConeSphereIntersection(![Vector](Type-Vector.png "Vector") Start, ![Vector](Type-Vector.png "Vector") Dir, ![Number](Type-Number.png "Number") Angle)

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:sortByDistance(![Vector](Type-Vector.png "Vector") Pos)

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:count()

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:hit()

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:hit(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:hitAngle()

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:hitAngle(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:index()

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:index(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:distance()

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:distance(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:radius()

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:radius(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:rotation()

 (0 ops)

### ![Number](Type-Number.png "Number") = Tracedata:rotation(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![String](Type-String.png "String") = Tracedata:model()

 (0 ops)

### ![String](Type-String.png "String") = Tracedata:model(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = Tracedata:hitPos()

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = Tracedata:hitPos(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = Tracedata:pos()

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = Tracedata:pos(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = Tracedata:vertices()

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = Tracedata:vertices(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Angle](Type-Angle.png "Angle") = Tracedata:ang()

 (0 ops)

### ![Angle](Type-Angle.png "Angle") = Tracedata:ang(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = Tracedata:hitNormal()

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = Tracedata:hitNormal(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = Tracedata:size()

 (0 ops)

### ![Vector](Type-Vector.png "Vector") = Tracedata:size(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Entity](Type-Entity.png "Entity") = Tracedata:parent()

 (0 ops)

### ![Entity](Type-Entity.png "Entity") = Tracedata:parent(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Entity](Type-Entity.png "Entity") = Tracedata:entity()

 (0 ops)

### ![Entity](Type-Entity.png "Entity") = Tracedata:entity(![Number](Type-Number.png "Number") Index)

 (0 ops)

### ![Entity](Type-Entity.png "Entity") = Tracedata:owner()

 (0 ops)

### ![Entity](Type-Entity.png "Entity") = Tracedata:owner(![Number](Type-Number.png "Number") Index)

 (0 ops)
