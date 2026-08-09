[Jump to table of contents](#default-extensions)

# Color

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):getColor()

Returns the color of an entity as a vector (R,G,B) (2 ops)

### ![Vector4](Type-Vector4.png "Vector4") = ![Entity](Type-Entity.png "Entity"):getColor4()

Returns the color of an entity as a 4D vector (R,G,B,A) (2 ops)

### ![Number](Type-Number.png "Number") = ![Entity](Type-Entity.png "Entity"):getAlpha()

Returns the alpha of an entity (2 ops)

### ![Entity](Type-Entity.png "Entity"):setColor(![Number](Type-Number.png "Number") R, ![Number](Type-Number.png "Number") G, ![Number](Type-Number.png "Number") B)

Sets the color of the entity (2 ops)

### ![Entity](Type-Entity.png "Entity"):setColor(![Number](Type-Number.png "Number") R, ![Number](Type-Number.png "Number") G, ![Number](Type-Number.png "Number") B, ![Number](Type-Number.png "Number") A)

Sets the color and alpha of the entity (2 ops)

### ![Entity](Type-Entity.png "Entity"):setColor(![Vector](Type-Vector.png "Vector") C)

Sets the color of the entity (2 ops)

### ![Entity](Type-Entity.png "Entity"):setColor(![Vector](Type-Vector.png "Vector") C, ![Number](Type-Number.png "Number") A)

Sets the color (as vector) and alpha (as number) of the entity (2 ops)

### ![Entity](Type-Entity.png "Entity"):setColor(![Vector4](Type-Vector4.png "Vector4") C)

Sets the color and alpha (as 4D vector) of the entity (2 ops)

### ![Entity](Type-Entity.png "Entity"):setAlpha(![Number](Type-Number.png "Number") A)

Sets the alpha of an entity (2 ops)

### ![Entity](Type-Entity.png "Entity"):setRenderMode(![Number](Type-Number.png "Number") Mode)

Sets the render mode of the entity (0 = Normal, 1 = TransColor, 2 = TransTexture, 3 = Glow, 4 = TransAlpha, 5 = TransAdd, 6 = Enviromental, 7 = TransAddFrameBlend, 8 = TransAlphaAdd, 9 = WorldGlow, 10 = None) (2 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):getPlayerColor()

Returns the player's model color as a vector (R,G,B) (2 ops)

### ![Vector](Type-Vector.png "Vector") = ![Entity](Type-Entity.png "Entity"):getWeaponColor()

Returns the player's weapon color as a vector (R,G,B) (2 ops)

### ![Entity](Type-Entity.png "Entity"):setWeaponColor(![Vector](Type-Vector.png "Vector") C)

 (2 ops)

### ![Entity](Type-Entity.png "Entity"):setPlayerColor(![Vector](Type-Vector.png "Vector") C)

 (2 ops)

### ![Vector](Type-Vector.png "Vector") = hsv2rgb(![Vector](Type-Vector.png "Vector") Hsv)

Converts V from the HSV color space to the RGB color space (2 ops)

### ![Vector](Type-Vector.png "Vector") = hsv2rgb(![Number](Type-Number.png "Number") H, ![Number](Type-Number.png "Number") S, ![Number](Type-Number.png "Number") V)

Converts N,N,N from the HSV color space to the RGB color space (2 ops)

### ![Vector](Type-Vector.png "Vector") = rgb2hsv(![Vector](Type-Vector.png "Vector") Rgb)

Converts V from the RGB to the HSV color space (2 ops)

### ![Vector](Type-Vector.png "Vector") = rgb2hsv(![Number](Type-Number.png "Number") R, ![Number](Type-Number.png "Number") G, ![Number](Type-Number.png "Number") B)

Converts N,N,N from the RGB to the HSV color space (2 ops)

### ![Vector](Type-Vector.png "Vector") = hsl2rgb(![Vector](Type-Vector.png "Vector") Hsl)

Converts V from the HSL color space to the RGB color space (2 ops)

### ![Vector](Type-Vector.png "Vector") = hsl2rgb(![Number](Type-Number.png "Number") H, ![Number](Type-Number.png "Number") S, ![Number](Type-Number.png "Number") L)

Converts N,N,N from the HSL color space to the RGB color space (2 ops)

### ![Vector](Type-Vector.png "Vector") = rgb2hsl(![Vector](Type-Vector.png "Vector") Rgb)

Converts V from RGB color space to the HSL color space (2 ops)

### ![Vector](Type-Vector.png "Vector") = rgb2hsl(![Number](Type-Number.png "Number") R, ![Number](Type-Number.png "Number") G, ![Number](Type-Number.png "Number") B)

Converts N,N,N from RGB color space to the HSL color space (2 ops)

### ![Number](Type-Number.png "Number") = rgb2digi(![Vector](Type-Vector.png "Vector") Rgb, ![Number](Type-Number.png "Number") Mode)

Converts the RGB vector V to a number in digital screen format. N Specifies a mode, either 0, 2 or 3, corresponding to Digital Screen color modes (2 ops)

### ![Number](Type-Number.png "Number") = rgb2digi(![Number](Type-Number.png "Number") R, ![Number](Type-Number.png "Number") G, ![Number](Type-Number.png "Number") B, ![Number](Type-Number.png "Number") Mode)

Converts the RGB color (N,N2,N3) to a number in digital screen format. N4 Specifies a mode, either 0, 2 or 3, corresponding to Digital Screen color modes (2 ops)
