### What are quaternions?

To explain it well, we need to start at what are complex numbers.
The regular numbers, that everyone is used to, are the real numbers. But they have a drawback - there are equations that don't have solutions in real numbers, like x^2=-1. There is no real number that squared gives -1. That's why people invented complex numbers. A number that when squared gives -1 is i, called an imaginary unit.

A complex number is a number like a+bi, where a and b are real. They have many great properties, but this is not the matter of this tutorial. To give you a quick feel how calculations on complex numbers work, here are a few examples:

Assume we have two complex numbers, z = a+bi and w = c+di (a, b, c, d are real). Then:

    z+w = a+bi + c+di = (a+c) + (b+d)i
    z*w = (a+bi)(c+di) = ac + adi + bic + bidi = ac + adi + bci - bd = (ac-bd)+(ad+bc)i
    z/w = (a+bi)/(c+di) = [(a+bi)(c-di)]/[(c+di)(c-di)] = [(ac+bd)+(bc-ad)i]/[(cc+dd)+(cd-cd)i] = [(ac+bd)+(bc-ad)i]/(c^2+d^2)

It might be not very readable at the first glance, but if you read it a few times, I'm sure you will see how it works. It's just like with real numbers, except we have i and we have to remember that i^2=-1.

Ok, so now, quaternions. Quaternions extend the idea of complex numbers to 3 imaginary units. They are called i, j and k. All three work like i in this sense, that i^2 = j^2 = k^2 = -1. But! Beware, quaternions are tricky, because their multiplication isn't commutative! Here is how it works:

    i^2 = j^2 = k^2 = ijk = -1
    ij = -ji = k
    jk = -kj = i
    ki = -ik = j

I will not look into addition and multiplication of quaternions, because it's not that important and it would take a lot of text to write it all. Besides, it wouldn't be readable at all

### How are they useful?

The quaternions appeared to be very useful in representing rotations. Those of you, who use applyAngForce know the problem of gimbal lock near 90 degrees pitch. Quaternions are a great way to avoid that.

Imaginary units i, j and k make a great basis in 3D space. For example, 3i + 5j - 2k is very similar to a [3,5,-2] vector. That's why people sometimes write quaternions as a+v, instead of usual a+bi+cj+dk.

Now, we can do that the other way round. Get a vector from 3D space and treat it like a quaternion with real part (the "a" number) equal to 0.

It turns out, that if we take a quaternion q = cos(x/2)+vsin(x/2) (where x is an angle and v is a unit vector) and vector w, then:
    q w (1/q)
is vector w rotated by angle x about axis v. Confusing? Let's see an example.

We want to rotate vector [3,5,-2] 90 degrees about X axis. Our angle x is 90 and axis v is [1,0,0] (X axis). The quaternion q is:

    q = cos(45) + [1,0,0]*sin(45) = 0.707 + 0.707*i

It turns out, that:

    1/q = 0.707 - 0.707*i

Vector w, as a quaternion, is 3i + 5j - 2k. Now we have to calculate:

    (0.707+0.707*i)(3i+5j-2k)(0.707-0.707*i) = (after many calculations) = 3i + 2j + 5k

So, the rotated vector is [3,2,5].

Fortunately, in E2 the chip does all the calculations for you

One more thing: let's see what happens, if I rotate a vector using 1/q.

    RotatedV = (1/q) V (1/(1/q)) = (1/q) V q

Now rotate it with q again:

    RotatedV2 = q RotatedV (1/q) = q (1/q) V q (1/q) = 1*V*1 = V

The point is: rotation by (1/q) is a rotation in the opposite direction than rotation by q, and by the same angle.

### Representing orientation with quaternions

Here we come to the really useful things.

An orientation, or an angle as it's called in E2 can be considered a rotation from orientation (0,0,0) about some axis by some angle. As that, it can be represented by a quaternion. For example, quaternion 1 (no rotation) means (0,0,0), so 0 pitch, 0 yaw, 0 roll. Quaternion 1k is rotation by 180 degrees about Z axis, so it's 0 pitch, 180 yaw, 0 roll.

Now, imagine we have two angles given, like current orientation and target orientation, and we want to know how to rotate between them. Practical example: you have a turret and you want it to chase a target. We have Turret:angle() and a vector, DirectionToTarget. So, we have something like this:

    CurrentQuat = quat(Turret:angle()) #or just quat(Turret)
    TargetQuat = quat(DirectionToTarget:toAngle())

How to calculate a quaternion that will rotate between those two orientations? First, remember that CurrentQuat is rotation from (0,0,0) to current orientation, and TargetQuat is rotation from (0,0,0) to target orientation. So, to rotate from CurrentQuat to TargetQuat, we need to rotate from CurrentQuat to (0,0,0) and from (0,0,0) to TargetQuat!

Rotation from CurrentQuat to (0,0,0) is 1/CurrentQuat, or inv(CurrentQuat).
Rotation from (0,0,0) to TargetQuat is... TargetQuat.
So - rotation from CurrentQuat to TargetQuat is TargetQuat*inv(CurrentQuat), or just TargetQuat/CurrentQuat!

    CurrentQuat = quat(Turret:angle()) #or just quat(Turret)
    TargetQuat = quat(DirectionToTarget:toAngle())
    Q = TargetQuat/CurrentQuat

Now we want to find out about what axis and by what angle we have to rotate. There are 3 convenient functions for that:

1. rotationAxis(Q) - will return a unit vector, representing the axis.
2. rotationAngle(Q) - will return a number, that is the angle by which we have to rotate.
3. rotationVector(Q) - will return a vector, that direction is the axis, and its magnitude is the angle.

Wait... rotationVector() is perfect for applyTorque! We need to rotate about exactly this axis and we want to rotate stronger when we are further away from target, that is, when the angle is greater! The only drawback is that applyTorque needs an intrinsic vector and rotationVector returns an extrinsic one, but this can easily be fixed:

    Torque = Turret:toLocal(rotationVector(Q)+Turret:pos())

Finally, we will use angVelVector as the delta term and we have:

    CurrentQuat = quat(Turret:angle()) #or just quat(Turret)
    TargetQuat = quat(DirectionToTarget:toAngle())
    Q = TargetQuat/CurrentQuat
    Torque = Turret:toLocal(rotationVector(Q)+Turret:pos())

    Turret:applyTorque((Torque*N - Turret:angVelVector()*M)*Turret:inertia())

N and M are some constants that have to be adjusted for best performance.

### Summary

This of course isn't all you can do with quaternions, but it will probably be the most popular use If you have any questions, post them and I will try to clear things up. I hope this tutorial will be useful for you.

You can read more on this topic here: [http://en.wikipedia.org/wiki/Quatern...atial_rotation](http://web.archive.org/web/20160520180807/http://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation)

### What to learn if you can't understand this

Here is a short list of topics to research, that can help you in understanding quaternions:

* Complex numbers - quaternions are a generalization of complex numbers, so it's good to start with them
* Vector spaces, linear transformations - that's what rotations are all about
* Groups - some basics of group theory (what are groups, examples of groups) can help you understand how quaternions work
* https://www.youtube.com/watch?v=d4EgbgTm0Bg
* https://www.youtube.com/watch?v=zjMuIxRvygQ


Credit for this guide goes to [@fizyk20](https://github.com/fizyk20)