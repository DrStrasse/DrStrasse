[Jump to table of contents](#table-of-contents)

# Custom/stcontrol

### Stcontrol = noStControl()

Returns invalid state control object (1 ops)

### Stcontrol = newStControl()

Returns state control object with dynamic sampling time (20 ops)

### Stcontrol = newStControl(![Number](Type-Number.png "Number") Nto)

Returns state control object with static sampling time (20 ops)

### Stcontrol = Stcontrol:getCopy()

Returns state control object copy instance (20 ops)

### Stcontrol = Stcontrol:getCopy(![Number](Type-Number.png "Number") Nt)

Returns state control object copy instance with static sampling time (20 ops)

### Stcontrol = Stcontrol:setGainP(![Number](Type-Number.png "Number") Np)

Updates state control proportional term gain (7 ops)

### Stcontrol = Stcontrol:setGainI(![Number](Type-Number.png "Number") Ni)

Updates state control integral term gain (7 ops)

### Stcontrol = Stcontrol:setGainD(![Number](Type-Number.png "Number") Nd)

Updates state control derivative term gain (7 ops)

### Stcontrol = Stcontrol:setGainPI(![Number](Type-Number.png "Number") Np, ![Number](Type-Number.png "Number") Ni)

Updates state control proportional term gain and integral term gain (7 ops)

### Stcontrol = Stcontrol:setGainPI(![Vector2](Type-Vector2.png "Vector2") Vv)

Updates state control proportional term gain and integral term gain (7 ops)

### Stcontrol = Stcontrol:setGainPI(![Array](Type-Array.png "Array") Aa)

Updates state control proportional term gain and integral term gain (7 ops)

### Stcontrol = Stcontrol:setGainPD(![Number](Type-Number.png "Number") Np, ![Number](Type-Number.png "Number") Nd)

Updates state control proportional term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:setGainPD(![Vector2](Type-Vector2.png "Vector2") Vv)

Updates state control proportional term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:setGainPD(![Array](Type-Array.png "Array") Aa)

Updates state control proportional term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:setGainID(![Number](Type-Number.png "Number") Ni, ![Number](Type-Number.png "Number") Nd)

Updates state control integral term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:setGainID(![Vector2](Type-Vector2.png "Vector2") Vv)

Updates state control derivative term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:setGainID(![Array](Type-Array.png "Array") Aa)

Updates state control integral term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:setGain(![Number](Type-Number.png "Number") Np, ![Number](Type-Number.png "Number") Ni, ![Number](Type-Number.png "Number") Nd)

Updates state control proportional term gain, integral term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:setGain(![Array](Type-Array.png "Array") Aa)

Updates state control proportional term gain, integral term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:setGain(![Vector](Type-Vector.png "Vector") Vv)

Updates state control proportional term gain, integral term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:remGainP()

Removes state control proportional term gain (7 ops)

### Stcontrol = Stcontrol:remGainI()

Removes state control integral term gain (7 ops)

### Stcontrol = Stcontrol:remGainD()

Removes state control derivative term gain (7 ops)

### Stcontrol = Stcontrol:remGainPI()

Removes state control proportional term gain and integral term gain (7 ops)

### Stcontrol = Stcontrol:remGainPD()

Removes state control proportional term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:remGainID()

Removes state control integral term gain and derivative term gain (7 ops)

### Stcontrol = Stcontrol:remGain()

Removes state control proportional term gain, integral term gain and derivative term gain (7 ops)

### ![Vector](Type-Vector.png "Vector") = Stcontrol:getGain()

Returns state control proportional term gain, integral term gain and derivative term gain (3 ops)

### ![Vector2](Type-Vector2.png "Vector2") = Stcontrol:getGainPI()

Returns state control proportional term gain and integral term gain (3 ops)

### ![Vector2](Type-Vector2.png "Vector2") = Stcontrol:getGainPD()

Returns state control proportional term gain and derivative term gain (3 ops)

### ![Vector2](Type-Vector2.png "Vector2") = Stcontrol:getGainID()

Returns state control integral term gain and derivative term gain (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getGainP()

Returns state control proportional term gain (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getGainI()

Returns state control integral term gain (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getGainD()

Returns state control derivative term gain (3 ops)

### Stcontrol = Stcontrol:setBias(![Number](Type-Number.png "Number") Nn)

Updates state control control bias (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getBias()

Returns state control control bias (3 ops)

### ![String](Type-String.png "String") = Stcontrol:getType()

Returns state control control type (3 ops)

### Stcontrol = Stcontrol:setWindup(![Number](Type-Number.png "Number") Nd, ![Number](Type-Number.png "Number") Nu)

Updates state control windup lower bound and windup upper bound (3 ops)

### Stcontrol = Stcontrol:setWindup(![Array](Type-Array.png "Array") Aa)

Updates state control windup lower bound and windup upper bound (3 ops)

### Stcontrol = Stcontrol:setWindup(![Vector2](Type-Vector2.png "Vector2") Vv)

Updates state control windup lower bound and windup upper bound (3 ops)

### Stcontrol = Stcontrol:setWindupD(![Number](Type-Number.png "Number") Nd)

Updates state control windup lower bound (3 ops)

### Stcontrol = Stcontrol:setWindupU(![Number](Type-Number.png "Number") Nu)

Updates state control windup upper bound (3 ops)

### Stcontrol = Stcontrol:remWindup()

Removes state control windup lower bound and windup upper bound (3 ops)

### Stcontrol = Stcontrol:remWindupD()

Removes state control windup lower bound (3 ops)

### Stcontrol = Stcontrol:remWindupU()

Removes state control windup upper bound (3 ops)

### ![Vector2](Type-Vector2.png "Vector2") = Stcontrol:getWindup()

Returns state control windup lower bound and windup upper bound (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getWindupD()

Returns state control windup lower bound (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getWindupU()

Returns state control windup upper bound (3 ops)

### Stcontrol = Stcontrol:setPowerP(![Number](Type-Number.png "Number") Np)

Updates state control proportional term power (8 ops)

### Stcontrol = Stcontrol:setPowerI(![Number](Type-Number.png "Number") Ni)

Updates state control integral term power (8 ops)

### Stcontrol = Stcontrol:setPowerD(![Number](Type-Number.png "Number") Nd)

Updates state control derivative term power (8 ops)

### Stcontrol = Stcontrol:setPowerPI(![Number](Type-Number.png "Number") Np, ![Number](Type-Number.png "Number") Ni)

Updates state control proportional term power and integral term power (8 ops)

### Stcontrol = Stcontrol:setPowerPI(![Vector2](Type-Vector2.png "Vector2") Vv)

Updates state control proportional term power and integral term power (8 ops)

### Stcontrol = Stcontrol:setPowerPI(![Array](Type-Array.png "Array") Aa)

Updates state control proportional term power and integral term power (8 ops)

### Stcontrol = Stcontrol:setPowerPD(![Number](Type-Number.png "Number") Np, ![Number](Type-Number.png "Number") Nd)

Updates state control proportional term power and derivative term power (8 ops)

### Stcontrol = Stcontrol:setPowerPD(![Vector2](Type-Vector2.png "Vector2") Vv)

Updates state control proportional term power and derivative term power (8 ops)

### Stcontrol = Stcontrol:setPowerPD(![Array](Type-Array.png "Array") Aa)

Updates state control proportional term power and derivative term power (8 ops)

### Stcontrol = Stcontrol:setPowerID(![Number](Type-Number.png "Number") Ni, ![Number](Type-Number.png "Number") Nd)

Updates state control integral term power and derivative term power (8 ops)

### Stcontrol = Stcontrol:setPowerID(![Vector2](Type-Vector2.png "Vector2") Vv)

Updates state control derivative term power and derivative term power (8 ops)

### Stcontrol = Stcontrol:setPowerID(![Array](Type-Array.png "Array") Aa)

Updates state control integral term power and derivative term power (8 ops)

### Stcontrol = Stcontrol:setPower(![Number](Type-Number.png "Number") Np, ![Number](Type-Number.png "Number") Ni, ![Number](Type-Number.png "Number") Nd)

Updates state control proportional term power, integral term power and derivative term power (8 ops)

### Stcontrol = Stcontrol:setPower(![Array](Type-Array.png "Array") Aa)

Updates state control proportional term power, integral term power and derivative term power (8 ops)

### Stcontrol = Stcontrol:setPower(![Vector](Type-Vector.png "Vector") Vv)

Updates state control proportional term power, integral term power and derivative term power (8 ops)

### ![Vector](Type-Vector.png "Vector") = Stcontrol:getPower()

Returns state control proportional term power, integral term power and derivative term power (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getPowerP()

Returns state control proportional term power (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getPowerI()

Returns state control integral term power (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getPowerD()

Returns state control derivative term power (3 ops)

### ![Vector2](Type-Vector2.png "Vector2") = Stcontrol:getPowerPI()

Returns state control proportional term power and integral term power (3 ops)

### ![Vector2](Type-Vector2.png "Vector2") = Stcontrol:getPowerPD()

Returns state control proportional term power and derivative term power (3 ops)

### ![Vector2](Type-Vector2.png "Vector2") = Stcontrol:getPowerID()

Returns state control integral term power and derivative term power (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getErrorNow()

Returns state control process current error (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getErrorOld()

Returns state control process passed error (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getErrorDelta()

Returns state control process error delta (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getTimeNow()

Returns state control process current time (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getTimeOld()

Returns state control process passed time (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getTimeDelta()

Returns state control dynamic process time delta (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getTimeSample()

Returns state control static process time delta (3 ops)

### Stcontrol = Stcontrol:setTimeSample(![Number](Type-Number.png "Number") Nt)

Updates state control static process time delta (3 ops)

### Stcontrol = Stcontrol:remTimeSample()

Removes state control static process time delta (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getTimeBench()

Returns state control process benchmark time (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getTimeRatio()

Returns state control process time ratio (3 ops)

### Stcontrol = Stcontrol:setIsIntegral(![Number](Type-Number.png "Number") Nn)

Updates integral enabled flag (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:isIntegral()

Checks integral enabled flag (3 ops)

### Stcontrol = Stcontrol:setIsDerivative(![Number](Type-Number.png "Number") Nn)

Updates derivative enabled flag (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:isDerivative()

Checks derivative enabled flag (3 ops)

### Stcontrol = Stcontrol:setIsCombined(![Number](Type-Number.png "Number") Nn)

Updates combined flag spreading proportional term gain across others (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:isCombined()

Checks state control combined flag spreading proportional term gain across others (3 ops)

### Stcontrol = Stcontrol:setIsManual(![Number](Type-Number.png "Number") Nn)

Updates state control manual control signal value (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:isManual()

Checks state control manual control flag (3 ops)

### Stcontrol = Stcontrol:setManual(![Number](Type-Number.png "Number") Nn)

Updates state control manual control value (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getManual()

Returns state control manual control signal value (3 ops)

### Stcontrol = Stcontrol:setIsInverted(![Number](Type-Number.png "Number") Nn)

Updates state control inverted feedback flag of the reference and set-point (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:isInverted()

Checks state control inverted feedback flag of the reference and set-point (3 ops)

### Stcontrol = Stcontrol:setIsActive(![Number](Type-Number.png "Number") Nn)

Updates state control activated working flag (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:isActive()

Checks state control activated working flag (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getControl()

Returns state control automated control signal signal (3 ops)

### ![Vector](Type-Vector.png "Vector") = Stcontrol:getControlTerm()

Returns state control automated control term signal (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getControlTermP()

Returns state control proportional automated control term signal (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getControlTermI()

Returns state control integral automated control term signal (3 ops)

### ![Number](Type-Number.png "Number") = Stcontrol:getControlTermD()

Returns state control derivative automated control term signal (3 ops)

### Stcontrol = Stcontrol:resState()

Resets state control automated internal parameters (3 ops)

### Stcontrol = Stcontrol:setState(![Number](Type-Number.png "Number") Nr, ![Number](Type-Number.png "Number") Ny)

Works state control automated internal parameters (20 ops)

### Stcontrol = Stcontrol:tuneAutoZN(![Number](Type-Number.png "Number") Uk, ![Number](Type-Number.png "Number") Ut)

Tunes the state control using the Ziegler-Nichols auto-oscillation method (ZN) (7 ops)

### Stcontrol = Stcontrol:tuneAutoZN(![Number](Type-Number.png "Number") Uk, ![Number](Type-Number.png "Number") Ut, ![String](Type-String.png "String") Sm)

Tunes the state control using the Ziegler-Nichols auto-oscillation method with overshot option (ZN) (7 ops)

### Stcontrol = Stcontrol:tuneProcZN(![Number](Type-Number.png "Number") Uk, ![Number](Type-Number.png "Number") Ut, ![Number](Type-Number.png "Number") Ul)

Tunes the state control using the Ziegler-Nichols plant process method (ZN) (7 ops)

### Stcontrol = Stcontrol:tuneProcCC(![Number](Type-Number.png "Number") Nk, ![Number](Type-Number.png "Number") Nt, ![Number](Type-Number.png "Number") Nl)

Tunes the state control using the Choen-Coon method (CC) (7 ops)

### Stcontrol = Stcontrol:tuneProcCHRSP(![Number](Type-Number.png "Number") Nk, ![Number](Type-Number.png "Number") Nt, ![Number](Type-Number.png "Number") Nl)

Tunes the state control using the Chien-Hrones-Reswick method (CHR) set point track (7 ops)

### Stcontrol = Stcontrol:tuneOverCHRSP(![Number](Type-Number.png "Number") Nk, ![Number](Type-Number.png "Number") Nt, ![Number](Type-Number.png "Number") Nl)

Tunes the state control using the Chien-Hrones-Reswick method (CHR) set point track 20% overshot (7 ops)

### Stcontrol = Stcontrol:tuneProcCHRLR(![Number](Type-Number.png "Number") Nk, ![Number](Type-Number.png "Number") Nt, ![Number](Type-Number.png "Number") Nl)

Tunes the state control using the Chien-Hrones-Reswick method (CHR) load rejection (7 ops)

### Stcontrol = Stcontrol:tuneOverCHRLR(![Number](Type-Number.png "Number") Nk, ![Number](Type-Number.png "Number") Nt, ![Number](Type-Number.png "Number") Nl)

Tunes the state control using the Chien-Hrones-Reswick method (CHR) load rejection 20% overshot (7 ops)

### Stcontrol = Stcontrol:tuneAH(![Number](Type-Number.png "Number") Nk, ![Number](Type-Number.png "Number") Nt, ![Number](Type-Number.png "Number") Nl)

Tunes the state control using the Astrom-Hagglund method (AH) (7 ops)

### Stcontrol = Stcontrol:tuneISE(![Number](Type-Number.png "Number") Nk, ![Number](Type-Number.png "Number") Nt, ![Number](Type-Number.png "Number") Nl)

Tunes the state control using the integral square error method (ISE) (7 ops)

### Stcontrol = Stcontrol:tuneIAE(![Number](Type-Number.png "Number") Nk, ![Number](Type-Number.png "Number") Nt, ![Number](Type-Number.png "Number") Nl)

Tunes the state control using the integral absolute error method (IAE) (7 ops)

### Stcontrol = Stcontrol:tuneITAE(![Number](Type-Number.png "Number") Nk, ![Number](Type-Number.png "Number") Nt, ![Number](Type-Number.png "Number") Nl)

Tunes the state control using the integral of time-weighted absolute error method (ITAE) (7 ops)

### Stcontrol = Stcontrol:dumpItem(![Number](Type-Number.png "Number") Nn)

Dumps state control to the chat area by number identifier (15 ops)

### Stcontrol = Stcontrol:dumpItem(![String](Type-String.png "String") Sn)

Dumps state control to the chat area by string identifier (15 ops)

### Stcontrol = Stcontrol:dumpItem(![String](Type-String.png "String") Nt, ![Number](Type-Number.png "Number") Nn)

Dumps state control by number identifier in the specified area by first argument (15 ops)

### Stcontrol = Stcontrol:dumpItem(![String](Type-String.png "String") Nt, ![String](Type-String.png "String") Sn)

Dumps state control by string identifier in the specified area by first argument (15 ops)
