This page contains a complete list of EGP objects and their fields that can be modified in E2.
<!-- Todo: image examples -->
<!-- Todo: relevant functions -->
<!-- Todo: private fields, e.g. CanTopLeft, ID -->
## 3D Tracker
Maps a world position to a position on the EGP relative to the player. Currently not entirely accurate on EGP Screens.
> ![WireLink](Type-WireLink.png "WireLink"):egp3DTracker(![Number](Type-Number.png "Number") index, ![Vector](Type-Vector.png "Vector") pos[, ![Number](Type-Number.png "Number") directionality])

| Public Fields                                      | Description                                                                                                                    | Default value |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------- |
| ![Number](Type-Number.png "Number") angle          | The angle of the object                                                                                                        | 0             |
| ![Number](Type-Number.png "Number") directionality | Specifies whether the object is visible behind (-1), in front of (1) the EGP, or both (0). HUD is unaffected by directionality | 0             |
| ![Number](Type-Number.png "Number") filtering      | The texture filter enum of the object                                                                                          | 3             |
| ![Entity](Type-Entity.png "Entity") parententity   | The parent entity of the object                                                                                                | NULL          |
| ![Number](Type-Number.png "Number") target_x       | The x position of the tracker relative to the world or parententity                                                            | 0             |
| ![Number](Type-Number.png "Number") target_y       | The y position of the tracker relative to the world or parententity                                                            | 0             |
| ![Number](Type-Number.png "Number") target_z       | The z position of the tracker relative to the world or parententity                                                            | 0             |
| ![Number](Type-Number.png "Number") x              | The x position of the object                                                                                                   | 0             |
| ![Number](Type-Number.png "Number") y              | The y position of the object                                                                                                   | 0             |

## Box
A filled rectangle.
> ![WireLink](Type-WireLink.png "WireLink"):egpBox(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2") pos, ![Vector2](Type-Vector2.png "Vector2") size)

| Public Fields                                 | Description                           | Default value |
| --------------------------------------------- | ------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object               | 255           |
| ![Number](Type-Number.png "Number") angle     | The angle of the object               | 0             |
| ![Number](Type-Number.png "Number") b         | The blue of the object                | 255           |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object               | 255           |
| ![Number](Type-Number.png "Number") h         | The height of the object              | 0             |
| ![String](Type-String.png "String") material  | The material of the object            | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                 | 255           |
| ![Number](Type-Number.png "Number") w         | The width of the object               | 0             |
| ![Number](Type-Number.png "Number") x         | The x position of the object          | 0             |
| ![Number](Type-Number.png "Number") y         | The y position of the object          | 0             |

## Box Outline
An outline of a rectangle.
> ![WireLink](Type-WireLink.png "WireLink"):egpBoxOutline(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2") pos, ![Vector2](Type-Vector2.png "Vector2") size)

| Public Fields                                 | Description                           | Default value |
| --------------------------------------------- | ------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object               | 255           |
| ![Number](Type-Number.png "Number") angle     | The angle of the object               | 0             |
| ![Number](Type-Number.png "Number") b         | The blue of the object                | 255           |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object               | 255           |
| ![Number](Type-Number.png "Number") h         | The height of the object              | 0             |
| ![String](Type-String.png "String") material  | The material of the object            | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                 | 255           |
| ![Number](Type-Number.png "Number") size      | The size of the outline               | 1             |
| ![Number](Type-Number.png "Number") w         | The width of the object               | 0             |
| ![Number](Type-Number.png "Number") x         | The x position of the object          | 0             |
| ![Number](Type-Number.png "Number") y         | The y position of the object          | 0             |

## Circle
A filled oval.
> ![WireLink](Type-WireLink.png "WireLink"):egpCircle(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2") pos, ![Vector2](Type-Vector2.png "Vector2") size)

| Public Fields                                 | Description                            | Default value |
| --------------------------------------------- | -------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object                | 255           |
| ![Number](Type-Number.png "Number") angle     | The angle of the object                | 0             |
| ![Number](Type-Number.png "Number") b         | The blue of the object                 | 255           |
| ![Number](Type-Number.png "Number") fidelity  | The number of vertices the circle uses | 180           |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object  | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object                | 255           |
| ![Number](Type-Number.png "Number") h         | The height of the object               | 0             |
| ![String](Type-String.png "String") material  | The material of the object             | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                  | 255           |
| ![Number](Type-Number.png "Number") w         | The width of the object                | 0             |
| ![Number](Type-Number.png "Number") x         | The x position of the object           | 0             |
| ![Number](Type-Number.png "Number") y         | The y position of the object           | 0             |

## Circle Outline
An outline of an oval.
> ![WireLink](Type-WireLink.png "WireLink"):egpCircleOutline(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2") pos, ![Vector2](Type-Vector2.png "Vector2") size)

| Public Fields                                 | Description                            | Default value |
| --------------------------------------------- | -------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object                | 255           |
| ![Number](Type-Number.png "Number") angle     | The angle of the object                | 0             |
| ![Number](Type-Number.png "Number") b         | The blue of the object                 | 255           |
| ![Number](Type-Number.png "Number") fidelity  | The number of vertices the circle uses | 180           |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object  | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object                | 255           |
| ![Number](Type-Number.png "Number") h         | The height of the object               | 0             |
| ![String](Type-String.png "String") material  | The material of the object             | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                  | 255           |
| ![Number](Type-Number.png "Number") size      | The size of the outline                | 1             |
| ![Number](Type-Number.png "Number") w         | The width of the object                | 0             |
| ![Number](Type-Number.png "Number") x         | The x position of the object           | 0             |
| ![Number](Type-Number.png "Number") y         | The y position of the object           | 0             |

## Line
A line between two points.
> ![WireLink](Type-WireLink.png "WireLink"):egpLine(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2") pos1, ![Vector2](Type-Vector2.png "Vector2") pos2)

| Public Fields                                 | Description                                 | Default value |
| --------------------------------------------- | ------------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object                     | 255           |
| ![Number](Type-Number.png "Number") angle     | The angle of the object                     | 0             |
| ![Number](Type-Number.png "Number") b         | The blue of the object                      | 255           |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object       | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object                     | 255           |
| ![String](Type-String.png "String") material  | The material of the object                  | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                       | 255           |
| ![Number](Type-Number.png "Number") size      | The size of the line                        | 1             |
| ![Number](Type-Number.png "Number") x         | The x position of the beginning of the line | 0             |
| ![Number](Type-Number.png "Number") x2        | The x position of the end of the line       | 0             |
| ![Number](Type-Number.png "Number") y         | The y position of the beginning of the line | 0             |
| ![Number](Type-Number.png "Number") y2        | The y position of the end of the line       | 0             |

## Line Strip
A line between multiple points.
> ![WireLink](Type-WireLink.png "WireLink"):egpLineStrip(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2")/![Vector4](Type-Vector4.png "Vector4") ...)

| Public Fields                                 | Description                                                                              | Default value |
| --------------------------------------------- | ---------------------------------------------------------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object                                                                  | 255           |
| ![Number](Type-Number.png "Number") angle     | The angle of the object                                                                  | 0             |
| ![Number](Type-Number.png "Number") b         | The blue of the object                                                                   | 255           |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object                                                    | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object                                                                  | 255           |
| ![String](Type-String.png "String") material  | The material of the object                                                               | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                                                                    | 255           |
| ![Number](Type-Number.png "Number") size      | The size of the line                                                                     | 1             |
| ![Table](Type-Table.png "Table") vertices     | The vertices of the line in the format `vertices[number] = { x = number, y = number }` | {}            |

## Poly
A filled polygon.
> ![WireLink](Type-WireLink.png "WireLink"):egpPoly(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2")/![Vector4](Type-Vector4.png "Vector4") ...)

| Public Fields                                 | Description                                                                              | Default value |
| --------------------------------------------- | ---------------------------------------------------------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object                                                                  | 255           |
| ![Number](Type-Number.png "Number") b         | The blue of the object                                                                   | 255           |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object                                                    | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object                                                                  | 255           |
| ![String](Type-String.png "String") material  | The material of the object                                                               | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                                                                    | 255           |
| ![Table](Type-Table.png "Table") vertices     | The vertices of the poly in the format `vertices[number] = { x = number, y = number }` | {}            |

## Poly Outline
A polygon outline.
> ![WireLink](Type-WireLink.png "WireLink"):egpPolyOutline(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2")/![Vector4](Type-Vector4.png "Vector4") ...)

| Public Fields                                 | Description                                                                              | Default value |
| --------------------------------------------- | ---------------------------------------------------------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object                                                                  | 255           |
| ![Number](Type-Number.png "Number") b         | The blue of the object                                                                   | 255           |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object                                                    | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object                                                                  | 255           |
| ![String](Type-String.png "String") material  | The material of the object                                                               | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                                                                    | 255           |
| ![Number](Type-Number.png "Number") size      | The size of the line                                                                     | 1             |
| ![Table](Type-Table.png "Table") vertices     | The vertices of the poly in the format `vertices[number] = { x = number, y = number }` | {}            |

## Rounded Box
A filled rectangle with curved corners.
> ![WireLink](Type-WireLink.png "WireLink"):egpRoundedBox(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2") pos, ![Vector2](Type-Vector2.png "Vector2") size)

| Public Fields                                 | Description                            | Default value |
| --------------------------------------------- | -------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object                | 255           |
| ![Number](Type-Number.png "Number") angle     | The angle of the object                | 0             |
| ![Number](Type-Number.png "Number") b         | The blue of the object                 | 255           |
| ![Number](Type-Number.png "Number") fidelity  | The number of vertices the corners use | 36            |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object  | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object                | 255           |
| ![Number](Type-Number.png "Number") h         | The height of the object               | 0             |
| ![String](Type-String.png "String") material  | The material of the object             | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                  | 255           |
| ![Number](Type-Number.png "Number") radius    | The radius of the corners              | 16            |
| ![Number](Type-Number.png "Number") w         | The width of the object                | 0             |
| ![Number](Type-Number.png "Number") x         | The x position of the object           | 0             |
| ![Number](Type-Number.png "Number") y         | The y position of the object           | 0             |

## Rounded Box Outline
A rectangle outline with curved corners.
> ![WireLink](Type-WireLink.png "WireLink"):egpRoundedBoxOutline(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2") pos, ![Vector2](Type-Vector2.png "Vector2") size)

| Public Fields                                 | Description                            | Default value |
| --------------------------------------------- | -------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object                | 255           |
| ![Number](Type-Number.png "Number") angle     | The angle of the object                | 0             |
| ![Number](Type-Number.png "Number") b         | The blue of the object                 | 255           |
| ![Number](Type-Number.png "Number") fidelity  | The number of vertices the corners use | 36            |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object  | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object                | 255           |
| ![Number](Type-Number.png "Number") h         | The height of the object               | 0             |
| ![String](Type-String.png "String") material  | The material of the object             | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                  | 255           |
| ![Number](Type-Number.png "Number") radius    | The radius of the corners              | 16            |
| ![Number](Type-Number.png "Number") size      | The size of the outline                | 1             |
| ![Number](Type-Number.png "Number") w         | The width of the object                | 0             |
| ![Number](Type-Number.png "Number") x         | The x position of the object           | 0             |
| ![Number](Type-Number.png "Number") y         | The y position of the object           | 0             |

## Text
A text object.
> ![WireLink](Type-WireLink.png "WireLink"):egpText(![Number](Type-Number.png "Number") index, ![String](Type-String.png "String") text, ![Vector2](Type-Vector2.png "Vector2") pos)

| Public Fields                                 | Description                            | Default value       |
| --------------------------------------------- | -------------------------------------- | ------------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object                | 255                 |
| ![Number](Type-Number.png "Number") angle     | The angle of the object                | 0                   |
| ![Number](Type-Number.png "Number") b         | The blue of the object                 | 255                 |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object  | 3                   |
| ![String](Type-String.png "String") font      | The font of the text                   | WireGPU_ConsoleFont |
| ![Number](Type-Number.png "Number") g         | The green of the object                | 255                 |
| ![Number](Type-Number.png "Number") halign    | The horizontal alignment of the object | 0                   |
| ![String](Type-String.png "String") material  | The material of the object             | ""                  |
| ![Number](Type-Number.png "Number") r         | The red of the object                  | 255                 |
| ![Number](Type-Number.png "Number") size      | The size of the text                   | 18                  |
| ![String](Type-String.png "String") text      | The text to display                    | ""                  |
| ![Number](Type-Number.png "Number") valign    | The vertical alignment of the text     | 0                   |
| ![Number](Type-Number.png "Number") x         | The x position of the object           | 0                   |
| ![Number](Type-Number.png "Number") y         | The y position of the object           | 0                   |

## Text Layout
A text object with width and height.
> ![WireLink](Type-WireLink.png "WireLink"):egpTextLayout(![Number](Type-Number.png "Number") index,![String](Type-String.png "String") text, ![Vector2](Type-Vector2.png "Vector2") pos, ![Vector2](Type-Vector2.png "Vector2") size)

| Public Fields                                 | Description                            | Default value       |
| --------------------------------------------- | -------------------------------------- | ------------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object                | 255                 |
| ![Number](Type-Number.png "Number") angle     | The angle of the object                | 0                   |
| ![Number](Type-Number.png "Number") b         | The blue of the object                 | 255                 |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object  | 3                   |
| ![String](Type-String.png "String") font      | The font of the text                   | WireGPU_ConsoleFont |
| ![Number](Type-Number.png "Number") g         | The green of the object                | 255                 |
| ![Number](Type-Number.png "Number") halign    | The horizontal alignment of the object | 0                   |
| ![Number](Type-Number.png "Number") h         | The height of the object               | 512                 |
| ![String](Type-String.png "String") material  | The material of the object             | ""                  |
| ![Number](Type-Number.png "Number") r         | The red of the object                  | 255                 |
| ![Number](Type-Number.png "Number") size      | The size of the text                   | 18                  |
| ![String](Type-String.png "String") text      | The text to display                    | ""                  |
| ![Number](Type-Number.png "Number") valign    | The vertical alignment of the text     | 0                   |
| ![Number](Type-Number.png "Number") w         | The width of the object                | 512                 |
| ![Number](Type-Number.png "Number") x         | The x position of the object           | 0                   |
| ![Number](Type-Number.png "Number") y         | The y position of the object           | 0                   |

## Wedge
A filled circle with a concave "mouth" portion.
> ![WireLink](Type-WireLink.png "WireLink"):egpWedge(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2") pos, ![Vector2](Type-Vector2.png "Vector2") size)

| Public Fields                                 | Description                           | Default value |
| --------------------------------------------- | ------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object               | 255           |
| ![Number](Type-Number.png "Number") angle     | The angle of the object               | 0             |
| ![Number](Type-Number.png "Number") b         | The blue of the object                | 255           |
| ![Number](Type-Number.png "Number") fidelity  | The number of vertices the wedge uses | 180           |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object               | 255           |
| ![Number](Type-Number.png "Number") h         | The height of the object              | 0             |
| ![String](Type-String.png "String") material  | The material of the object            | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                 | 255           |
| ![Number](Type-Number.png "Number") size      | The radius of the mouth of the wedge  | 45            |
| ![Number](Type-Number.png "Number") w         | The width of the object               | 0             |
| ![Number](Type-Number.png "Number") x         | The x position of the object          | 0             |
| ![Number](Type-Number.png "Number") y         | The y position of the object          | 0             |

## Wedge Outline
An outline of a wedge.
> ![WireLink](Type-WireLink.png "WireLink"):egpWedgeOutline(![Number](Type-Number.png "Number") index, ![Vector2](Type-Vector2.png "Vector2") pos, ![Vector2](Type-Vector2.png "Vector2") size)

| Public Fields                                 | Description                           | Default value |
| --------------------------------------------- | ------------------------------------- | ------------- |
| ![Number](Type-Number.png "Number") a         | The alpha of the object               | 255           |
| ![Number](Type-Number.png "Number") angle     | The angle of the object               | 0             |
| ![Number](Type-Number.png "Number") b         | The blue of the object                | 255           |
| ![Number](Type-Number.png "Number") fidelity  | The number of vertices the wedge uses | 180           |
| ![Number](Type-Number.png "Number") filtering | The texture filter enum of the object | 3             |
| ![Number](Type-Number.png "Number") g         | The green of the object               | 255           |
| ![Number](Type-Number.png "Number") h         | The height of the object              | 0             |
| ![String](Type-String.png "String") material  | The material of the object            | ""            |
| ![Number](Type-Number.png "Number") r         | The red of the object                 | 255           |
| ![Number](Type-Number.png "Number") size      | The radius of the mouth of the wedge  | 45            |
| ![Number](Type-Number.png "Number") w         | The width of the object               | 0             |
| ![Number](Type-Number.png "Number") x         | The x position of the object          | 0             |
| ![Number](Type-Number.png "Number") y         | The y position of the object          | 0             |