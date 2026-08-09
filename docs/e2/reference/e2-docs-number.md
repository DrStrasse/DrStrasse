[Jump to table of contents](#default-extensions)

# Number

### ![Number](Type-Number.png "Number") = min(![Number](Type-Number.png "Number") A, ![Number](Type-Number.png "Number") B)

Returns the lowest value Argument (1 ops)

### ![Number](Type-Number.png "Number") = min(![Number](Type-Number.png "Number") A, ![Number](Type-Number.png "Number") B, ![Number](Type-Number.png "Number") C)

Returns the lowest value Argument (1 ops)

### ![Number](Type-Number.png "Number") = min(![Number](Type-Number.png "Number") A, ![Number](Type-Number.png "Number") B, ![Number](Type-Number.png "Number") C, ![Number](Type-Number.png "Number") D)

Returns the lowest value Argument (1 ops)

### ![Number](Type-Number.png "Number") = max(![Number](Type-Number.png "Number") A, ![Number](Type-Number.png "Number") B)

Returns the highest value Argument (1 ops)

### ![Number](Type-Number.png "Number") = max(![Number](Type-Number.png "Number") A, ![Number](Type-Number.png "Number") B, ![Number](Type-Number.png "Number") C)

Returns the highest value Argument (1 ops)

### ![Number](Type-Number.png "Number") = max(![Number](Type-Number.png "Number") A, ![Number](Type-Number.png "Number") B, ![Number](Type-Number.png "Number") C, ![Number](Type-Number.png "Number") D)

Returns the highest value Argument (1 ops)

### ![Number](Type-Number.png "Number") = isfinite(![Number](Type-Number.png "Number") Value)

 (2 ops)

### ![Number](Type-Number.png "Number") = isinf(![Number](Type-Number.png "Number") Value)

Returns 1 if given value is a positive infinity or -1 if given value is a negative infinity; otherwise 0. (2 ops)

### ![Number](Type-Number.png "Number") = isnan(![Number](Type-Number.png "Number") Value)

Returns 1 if given value is not a number (NaN); otherwise 0. (2 ops)

### ![Number](Type-Number.png "Number") = remap(![Number](Type-Number.png "Number") Value, ![Number](Type-Number.png "Number") In_min, ![Number](Type-Number.png "Number") In_max, ![Number](Type-Number.png "Number") Out_min, ![Number](Type-Number.png "Number") Out_max)

Remaps an input value with an input minimum value and an input maximum value to an output minimum and output maximum. (2 ops)

### ![Number](Type-Number.png "Number") = abs(![Number](Type-Number.png "Number") N)

Returns the Magnitude of the Argument (2 ops)

### ![Number](Type-Number.png "Number") = ceil(![Number](Type-Number.png "Number") N)

Rounds the Argument up to the nearest Integer (2 ops)

### ![Number](Type-Number.png "Number") = ceil(![Number](Type-Number.png "Number") Value, ![Number](Type-Number.png "Number") Decimals)

Rounds Argument 1 up to Argument 2's decimal precision (2 ops)

### ![Number](Type-Number.png "Number") = floor(![Number](Type-Number.png "Number") N)

Rounds the Argument down to the nearest Integer (2 ops)

### ![Number](Type-Number.png "Number") = floor(![Number](Type-Number.png "Number") Value, ![Number](Type-Number.png "Number") Decimals)

Rounds Argument 1 down to Argument 2's decimal precision (2 ops)

### ![Number](Type-Number.png "Number") = round(![Number](Type-Number.png "Number") N)

Rounds the Argument to the nearest Integer (2 ops)

### ![Number](Type-Number.png "Number") = round(![Number](Type-Number.png "Number") Value, ![Number](Type-Number.png "Number") Decimals)

Rounds Argument 1 to Argument 2's decimal precision (2 ops)

### ![Number](Type-Number.png "Number") = int(![Number](Type-Number.png "Number") N)

Returns the Integer part of the Argument (always rounds towards zero) (2 ops)

### ![Number](Type-Number.png "Number") = frac(![Number](Type-Number.png "Number") N)

Returns the Fractional part (decimal places) of the Argument (2 ops)

### ![Number](Type-Number.png "Number") = mod(![Number](Type-Number.png "Number") Lhs, ![Number](Type-Number.png "Number") Rhs)

Modulo, returns the Remainder after Argument 1 has been divided by Argument 2. Note "mod(-1, 3) = -1" (2 ops)

### ![Number](Type-Number.png "Number") = wrap(![Number](Type-Number.png "Number") Lhs, ![Number](Type-Number.png "Number") Rhs)

Performs (n1 + n2) % (n2 * 2) - n2 (2 ops)

### ![Number](Type-Number.png "Number") = clamp(![Number](Type-Number.png "Number") N, ![Number](Type-Number.png "Number") Low, ![Number](Type-Number.png "Number") High)

If Arg1 = Arg3 (max) returns Arg3; otherwise returns Arg1 (2 ops)

### ![Number](Type-Number.png "Number") = inrange(![Number](Type-Number.png "Number") Value, ![Number](Type-Number.png "Number") Min, ![Number](Type-Number.png "Number") Max)

Returns 1 if N is in the interval [N2; N3], 0 otherwise. This means it is equivalent to ((N2 <= N) & (N <= N3)) (2 ops)

### ![Number](Type-Number.png "Number") = lerp(![Number](Type-Number.png "Number") From, ![Number](Type-Number.png "Number") To, ![Number](Type-Number.png "Number") Fraction)

Performs linear interpolation. Returns a new value between 'from' and 'to', based on a 0-1 percentage ('fraction') (2 ops)

### ![Number](Type-Number.png "Number") = sign(![Number](Type-Number.png "Number") N)

Returns the sign of argument (-1,0,1) [sign(N) = N / abs(N) ] (2 ops)

### ![Number](Type-Number.png "Number") = random()

Returns a random floating-point number between 0 and 1 [0 <= x < 1 ] (2 ops)

### ![Number](Type-Number.png "Number") = random(![Number](Type-Number.png "Number") N)

Returns a random floating-point number between 0 and the specified value [0 <= x < a ] (2 ops)

### ![Number](Type-Number.png "Number") = random(![Number](Type-Number.png "Number") Low, ![Number](Type-Number.png "Number") High)

Returns a random floating-point number between the specified interval [a <= x < b ] (2 ops)

### ![Number](Type-Number.png "Number") = randint(![Number](Type-Number.png "Number") N)

Returns a random integer from 1 to the specified value [1 <= x <= a ] (2 ops)

### ![Number](Type-Number.png "Number") = randint(![Number](Type-Number.png "Number") A, ![Number](Type-Number.png "Number") B)

Returns a random integer in the specified interval [a <= x <= b ] (2 ops)

### ![Number](Type-Number.png "Number") = factorial(![Number](Type-Number.png "Number") N)

Returns the Factorial of the Argument (10 ops)

### ![Number](Type-Number.png "Number") = sqrt(![Number](Type-Number.png "Number") N)

Returns the Square Root of the Argument (2 ops)

### ![Number](Type-Number.png "Number") = cbrt(![Number](Type-Number.png "Number") N)

Returns the Cube Root of the Argument (2 ops)

### ![Number](Type-Number.png "Number") = root(![Number](Type-Number.png "Number") N, ![Number](Type-Number.png "Number") Pow)

Returns the Nth Root of the first Argument (2 ops)

### ![Number](Type-Number.png "Number") = e()

Returns Euler's Constant (2 ops)

### ![Number](Type-Number.png "Number") = exp(![Number](Type-Number.png "Number") N)

Returns e to the power of the Argument (same as e()^N but shorter and faster this way) (2 ops)

### ![Vector2](Type-Vector2.png "Vector2") = frexp(![Number](Type-Number.png "Number") N)

Returns the mantissa and exponent of the given floating-point number as a vector2 (X component holds a mantissa, and Y component holds an exponent) (2 ops)

### ![Number](Type-Number.png "Number") = ln(![Number](Type-Number.png "Number") N)

Returns the logarithm to base e of the Argument (2 ops)

### ![Number](Type-Number.png "Number") = log2(![Number](Type-Number.png "Number") N)

Returns the logarithm to base 2 of the Argument (2 ops)

### ![Number](Type-Number.png "Number") = log10(![Number](Type-Number.png "Number") N)

Returns the logarithm to base 10 of the Argument (2 ops)

### ![Number](Type-Number.png "Number") = log(![Number](Type-Number.png "Number") A, ![Number](Type-Number.png "Number") B)

Returns the logarithm to base Argument 2 of Argument 1 (2 ops)

### ![Number](Type-Number.png "Number") = inf()

Returns a huge constant (infinity) (1 ops)

### ![Number](Type-Number.png "Number") = pi()

Returns the constant PI (1 ops)

### ![Number](Type-Number.png "Number") = toRad(![Number](Type-Number.png "Number") N)

Converts Degree angles to Radian angles (1 ops)

### ![Number](Type-Number.png "Number") = toDeg(![Number](Type-Number.png "Number") N)

Converts Radian angles to Degree angles (1 ops)

### ![Number](Type-Number.png "Number") = acos(![Number](Type-Number.png "Number") N)

Returns the inverse cosine of the argument, in degrees (2 ops)

### ![Number](Type-Number.png "Number") = asin(![Number](Type-Number.png "Number") N)

Returns the inverse sine of the argument, in degrees (2 ops)

### ![Number](Type-Number.png "Number") = atan(![Number](Type-Number.png "Number") N)

Returns the inverse tangent of the argument, in degrees (2 ops)

### ![Number](Type-Number.png "Number") = atan(![Number](Type-Number.png "Number") X, ![Number](Type-Number.png "Number") Y)

Returns the inverse tangent of the arguments (arg1 / arg2), in degrees. This function accounts for positive/negative arguments, and arguments at or close to 0 (2 ops)

### ![Number](Type-Number.png "Number") = atan2(![Number](Type-Number.png "Number") X, ![Number](Type-Number.png "Number") Y)

 (2 ops)

### ![Number](Type-Number.png "Number") = cos(![Number](Type-Number.png "Number") N)

Returns the cosine of N degrees (2 ops)

### ![Number](Type-Number.png "Number") = sec(![Number](Type-Number.png "Number") N)

Returns the secant of N degrees (2 ops)

### ![Number](Type-Number.png "Number") = sin(![Number](Type-Number.png "Number") N)

Returns the sine of N degrees (2 ops)

### ![Number](Type-Number.png "Number") = csc(![Number](Type-Number.png "Number") N)

Returns the cosecant of N degrees (2 ops)

### ![Number](Type-Number.png "Number") = tan(![Number](Type-Number.png "Number") N)

Returns the tangent of N degrees (2 ops)

### ![Number](Type-Number.png "Number") = cot(![Number](Type-Number.png "Number") N)

Returns the cotangent of N degrees (2 ops)

### ![Number](Type-Number.png "Number") = cosh(![Number](Type-Number.png "Number") N)

Returns the hyperbolic cosine of N degrees (1.5 ops)

### ![Number](Type-Number.png "Number") = sech(![Number](Type-Number.png "Number") N)

Returns the hyperbolic secant of N degrees (1.5 ops)

### ![Number](Type-Number.png "Number") = sinh(![Number](Type-Number.png "Number") N)

Returns the hyperbolic sine of N degrees (1.5 ops)

### ![Number](Type-Number.png "Number") = csch(![Number](Type-Number.png "Number") N)

Returns the hyperbolic cosecant of N degrees (1.5 ops)

### ![Number](Type-Number.png "Number") = tanh(![Number](Type-Number.png "Number") N)

Returns the hyperbolic tangent of N degrees (1.5 ops)

### ![Number](Type-Number.png "Number") = coth(![Number](Type-Number.png "Number") N)

Returns the hyperbolic cotangent of N degrees (1.5 ops)

### ![Number](Type-Number.png "Number") = acosr(![Number](Type-Number.png "Number") N)

Returns the inverse cosine of the argument, in radians (1.5 ops)

### ![Number](Type-Number.png "Number") = asinr(![Number](Type-Number.png "Number") N)

Returns the inverse sine of the argument, in radians (1.5 ops)

### ![Number](Type-Number.png "Number") = atanr(![Number](Type-Number.png "Number") N)

Returns the inverse tangent of the argument, in radians (1.5 ops)

### ![Number](Type-Number.png "Number") = cosr(![Number](Type-Number.png "Number") N)

Returns the cosine of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = secr(![Number](Type-Number.png "Number") N)

Returns the secant of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = sinr(![Number](Type-Number.png "Number") N)

Returns the sine of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = cscr(![Number](Type-Number.png "Number") N)

Returns the cosecant of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = tanr(![Number](Type-Number.png "Number") N)

Returns the tangent of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = cotr(![Number](Type-Number.png "Number") N)

Returns the cotangent of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = coshr(![Number](Type-Number.png "Number") N)

Returns the hyperbolic cosine of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = sechr(![Number](Type-Number.png "Number") N)

Returns the hyperbolic secant of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = sinhr(![Number](Type-Number.png "Number") N)

Returns the hyperbolic sine of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = cschr(![Number](Type-Number.png "Number") N)

Returns the hyperbolic cosecant of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = tanhr(![Number](Type-Number.png "Number") N)

Returns the hyperbolic tangent of N radians (1.5 ops)

### ![Number](Type-Number.png "Number") = cothr(![Number](Type-Number.png "Number") N)

Returns the hyperbolic cotangent of N radians (1.5 ops)

### ![String](Type-String.png "String") = toString(![Number](Type-Number.png "Number") Number)

Formats a number as a string. (Numbers may be concatenated into a string without using this function) (5 ops)

### ![String](Type-String.png "String") = ![Number](Type-Number.png "Number"):toString()

Formats a number as a string. (Numbers may be concatenated into a string without using this function) (5 ops)

### ![String](Type-String.png "String") = toString(![Number](Type-Number.png "Number") Number, ![Number](Type-Number.png "Number") Base)

Formats a number as a string, using argument 2 as the base. i.e. using 16 for base would convert the number to hex (10 ops)

### ![String](Type-String.png "String") = ![Number](Type-Number.png "Number"):toString(![Number](Type-Number.png "Number") Base)

Formats a number as a string, using argument 2 as the base. i.e. using 16 for base would convert the number to hex (10 ops)
