# Table of Contents

* [Intro](#intro)
* [Move a prop to a target location](#move-a-prop-to-a-target-location)
    * [Simple](#simple)
    * [Constant Speed](#constant-speed)
* [Rotate a prop to an angle](#rotate-a-prop-to-an-angle)
    * [applyTorque](#applyTorque)
    * [applyAngForce](#applyAngForce)
* [Ballistics](#ballistics)
# Intro

Physics, and especially the math behind it is hard. That is why this page contains useful snippets for some common problems.

All examples need to run **once** (and *only* once) per tick to work reliably, so use `event tick()` (or, less preferably, [[runOnTick()|E2:-Triggers#tick]]).  
You can run them on lower intervals if you can tolerate some lag/jitter and want to save some performance.

Unless specified otherwise, `E` is the **entity to move** and `Pos`, `Ang` will be the **target position/angle**.

# Move a prop to a target location

Notes:

* Do not use applyForce with setAng, they can interfere. Instead use `applyTorque` or `applyAngForce` as detailed below.
* If you want your prop to carry something (like a player), the easiest way to deal with that is increasing the mass of the prop you move such that any weight put on it will be insignificant. For a more thorough solution you could implement a PID controller if you feel comfortable with the math.

## Simple

Behavior: This starts with high acceleration but slows down as it approaches the target. Not very useful to transport something, but good for keeping stuff floating in place.  
For the math people, this will decrease the distance by a fixed *ratio* every tick, see the table below.

```golo
    # Compact version
    E:applyForce( ( (Pos-E:pos())*Mul/_TICKINTERVAL-E:vel() - propGravity()*_TICKINTERVAL )*E:mass() )
    
    # Detailed version
    local Difference = Pos-E:pos()
    local TargetVel = Difference*Mul/_TICKINTERVAL
    local Acceleration = TargetVel-E:vel()
    local AntiGravity = propGravity()*-1*_TICKINTERVAL
    E:applyForce( (Acceleration+AntiGravity)*E:mass() )
```

* `Mul` is the factor determining how fast the prop will be moving. In particular, you can calculate the distance after each tick as `NewDistance = OldDistance * Ratio`, or *NewDistance=OldDistance\*Ratio<sup>N</sup>* with N being the number of ticks passed. The distance traveled in one tick is `OldDistance * Mul`, so `Ratio = 1 - Mul`. The math people will tell you that you will never completely reach the target this way, but at some point you won't be able to notice it. The table below contains some example for `Mul`
* First we get the difference between the current and target positions as vector
* We then get the target velocity in `in / tick`, which will just be the difference multiplied by a scaling factor. Convert it to `in / s` dividing it by the number of seconds each tick takes (`_TICKINTERVAL`).  
You can think of this method as telling it to cover the distance to the target within 1/`Mul` ticks. However as we run continuously, the speed will decrease the closer we get.
* Now we can get the difference between the current velocity (velocity is a vector describing direction and speed) and the target velocity (what we calculated above). This gives us the velocity we need to add to the current velocity to reach the target velocity.
If you know some physics, you might remember that adding velocity is just called *acceleration* ( `u=u'+v` ).
* Additionally there are external forces being applied to the prop, such as gravity (Also drag, but not nearly as much as low speed).  
Since we run every tick, we just need to cancel out the acceleration due to gravity that would be applied in this tick to negate it completely. For that we take the gravity applied per second, invert it (since we want to push *up* to cancel it out) and multiply it by the number of seconds each tick takes (usually 0.015 s per tick)
* Finally we add both "forces" together and multiply by the mass of the prop (`F=m*a` for the physics people)

    Some examples for `Mul`:  
    Ratio is the ratio per tick (the formula above), RatioS is the ratio per second (`Ratio^(1 / _TICKINTERVAL)`) and "99% passed" is how long the prop will take to travel 99% of the way (calculated via `log(0.01) / log(Ratio) * _TICKINTERVAL`).

    |Mul|Ratio|RatioS|99% passed|
    |-:|:-|:-|:-|
    |1.000|**0.000**|0.000|0.00 s|
    |0.500|**0.500**|0.000|0.10 s|
    |0.067|0.933|0.010|**1.00 s**|
    |**0.045**|0.955|0.046|1.50 s|
    |**0.030**|0.970|0.131|2.27 s|
    |**0.015**|0.985|0.365|4.57 s|
    |0.010|0.990|**0.500**|6.64 s|
    |**1/128**|0.992|0.593|8.81 s|
    |**1/256**|0.996|0.770|17.65 s|
    |**1/512**|0.998|0.878|35.33 s|

    `Mul` defined through other columns:
    ```
    Mul = 1 - Ratio
    Mul = 1 - RatioS^_TICKINTERVAL
    Mul = 1 - 0.01^(_TICKINTERVAL / NnPassed)
    ```

## Constant speed

Behavior: Keeps a constant speed until very close. Good for transporting stuff, but can take a while

```golo
    # Compact version:
    local Diff = Pos-E:pos()
    E:applyForce( ( Diff*min(Speed/Diff:length(), 1)-E:vel() - propGravity()*tickInterval() )*E:mass() )
    
    # Detailed version
    local Difference = Pos-E:pos()
    local Distance = Difference:length()
    local TargetVel = Difference*min(Speed/Distance, 1)
    # Same as above from here
    local Acceleration = TargetVel-E:vel()
    local AntiGravity = propGravity()*-1*tickInterval()
    E:applyForce( (Acceleration+AntiGravity)*E:mass() )
```

To briefly explain the difference to the previous method:

* `Speed` is the desired speed is in hammer units per second (for scale, a player is 80 units tall).
* First we get the difference between the current and target positions as vector **and** number (distance)
* Then we cap the length of the difference vector to the maximum speed (making sure we don't actually increase it if the distance is less than speed), but keeping its original *direction*
* ...

# Rotate a prop to an angle

## applyTorque

```golo
    local Difference = E:toLocalAxis(rotationVector(quat(Ang) / quat(E)))
    local TargetAngularVelocity = Difference * Mul / _TICKINTERVAL
    local AngularVelocity = TargetAngularVelocity - E:angVelVector()
    E:applyTorque(AngularVelocity * E:inertia() / (180 / _PI / 39.3701^2))
```

To briefly explain this:

* Quaternions are a really cool way of representing angles, but quite complicated, so just take my word that `rotationVector(quat(Ang)/quat(E))` gets the rotation in X Y and Z axis that the entity has to rotate (`quat(E)` is equal to `quat(E:angles())`). To put it in simpler terms: The direction of that vector is the rotation axis, and the length describes the torque *around* that axis
* toLocalAxis takes that rotation, which is in the global coordinate system and transforms it to the local coordinate system of the prop (accounting for the current rotation)
* `Difference` is the angle between the current and target angles. As a base, we want to rotate the object by this angle in one tick, so a unit of this value is `degrees / tick`. Convert it to velocity dividing it by `_TICKINTERVAL`. Now this is `degrees / s`
* `Mul` is the same as in the applyTorque tutorial above. Tune it in range between 0 and 1 to fit your desired speed and smoothness
* Then we subtract angVel() to make it *not* keep accelerating until it passes the targe, and instead slow down before because speed is higher than what is needed to reach the target
* Finally we multiply with per-axis inertia, because rotating props takes different amount of torque depending on the axis (think how spinning a pole along its axis is much easier than trying to flip it). Its unit is `kg * m^2`
* Now we need convert `kg * m^2 * degrees / s` to an applyTorque unit which is `kg * in^2 * radians / s`, dividing it by `180 / _PI / 39.3701^2` [[ref]](https://github.com/wiremod/wire/blob/d921a7c4c399e57471d43c83d4c7536291746cc2/lua/entities/gmod_wire_expression2/core/entity.lua#L741)

## applyAngForce

```golo
     E:applyAngForce((E:toLocal(Angle)*200 - E:angVel()*20)*shiftL(ang(E:inertia())))
```

To briefly explain this:
* `E:toLocal(Angle)` gets the angle E would have to rotate to reach the target angle, a simple subtraction would cause problems because Angles wrap around from -180 to +180
* Subtract angVel() to make it *not* keep accelerating until it passes the target, and instead slow down before because speed is higher than what is needed to reach the target
* Instead of multiplying with mass you multiply with the inertia, but because it is given as a vector, one value for each rotation axis (X,Y,Z), it has to be converted to an angle and shifted to align with pitch(rotation around Y), yaw(rotation around Z) and roll(rotation around X)
* tune the 200 and 20 to fit your desired speed and smoothness

# Ballistics

(Based on a snippet by @Jacbo on the wiremod discord)

This function calculates the vector at which you need to launch something to reach a desired target.  
Note that this **does not simulate drag**, so you need to disable drag if you want accurate results.

This uses two formulas from basic physics ("Maximum Height" and "Free Fall" formula) and solves them to calculate the vertical velocity and from that the total airtime. Finally the required horizontal velocity to close the distance to the target within the airtime is calculated by a simple division.

The launch vector describes the *acceleration* needed to launch, so for a prop you want to cancel out currrent movement and then multiply by mass: `E:applyForce((LV-E:vel())*E:mass())`.

`AddHeight` lets you make the projectile arc by adding a additional height above either start or target point (depending on which is higher). I recommend scaling it with the distance so it doesn't look unnatural.

```golo
    function vector calcLaunchVector(Start:vector, Target:vector, AddHeight){
        #[ Detailed version
        # Height difference, positive if target is higher than start
        local TargetHeight=Target:z()-Start:z()
        # Height at the maximum of the trajectory
        local PeakHeight=AddHeight+max(TargetHeight,0)

        # first assume we fire straight up, with start being at height 0
        # Formula for peak height given upwards speed: `h_peak = v^2 / 2g`
        # Solving for v gives `v = sqrt(2g*h_peak)`
        local VerticalSpeed=sqrt(2*gravity()*PeakHeight)
        # This is the vertical speed we need to lauch at to reach the target peak height

        # Formula for distance fallen given starting velocity and elapsed time: `h = v*t - 1/2 * g*t^2`
        # Solving for t gives `t = (v+sqrt(v^2-2gh))/g`
        local Airtime = (VerticalSpeed+sqrt(VerticalSpeed^2-2*gravity()*TargetHeight))/gravity()
        # This is the time we spend from launching to reaching the *height* of the target, using our vertical launch speed
        # Note that how far we move horizontally during that time doesn't affect the result, so we can adjust horziontal speed indepentently

        # Now use the airtime to calculate the horizonal launch velocity
        local HorizontalDiff=vec2(Target-Start) # ignore z axis (height)
        local HorizontalVel=HorizontalDiff/Airtime # cover the whole horizontal distance during the flight time
        # This is adjusted to the projectile moves the exact horizontal difference to the target in the time it needs to reach the target height
        # So after the airtime, both height and horzontal position will be at the target, which means the projectile arrives perfectly 

        # finally combine horizontal speed (2d vector), and vertical speed (1d "vector") into a 3d vector
        return vec(HorizontalVel, VerticalSpeed)
        ]#

        # Compact version
        local VerticalSpeed=sqrt(2*gravity()*AddHeight+max(Target:z()-Start:z(),0))
        return vec(vec2(Target-Start)/(VerticalSpeed+sqrt(VerticalSpeed^2-2*gravity()*(Target:z()-Start:z()))/gravity()), VerticalSpeed)
    }
```