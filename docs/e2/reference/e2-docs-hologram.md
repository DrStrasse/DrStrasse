[Jump to table of contents](#default-extensions)

# Hologram

### ![Entity](Type-Entity.png "Entity") = holoCreate(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Position, ![Vector](Type-Vector.png "Vector") Scale, ![Angle](Type-Angle.png "Angle") Ang, ![Vector](Type-Vector.png "Vector") Color, ![String](Type-String.png "String") Model)

Index, Position, Scale, Angle, Color (RGB), Model
Creates a new hologram entity (30 ops)

### ![Entity](Type-Entity.png "Entity") = holoCreate(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Position, ![Vector](Type-Vector.png "Vector") Scale, ![Angle](Type-Angle.png "Angle") Ang, ![Vector4](Type-Vector4.png "Vector4") Color, ![String](Type-String.png "String") Model)

Index, Position, Scale, Angle, Color (RGBA), Model
Creates a new hologram entity (30 ops)

### ![Entity](Type-Entity.png "Entity") = holoCreate(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Position, ![Vector](Type-Vector.png "Vector") Scale, ![Angle](Type-Angle.png "Angle") Ang, ![Vector](Type-Vector.png "Vector") Color)

Index, Position, Scale, Angle, Color (RGB)
Creates a new hologram entity (30 ops)

### ![Entity](Type-Entity.png "Entity") = holoCreate(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Position, ![Vector](Type-Vector.png "Vector") Scale, ![Angle](Type-Angle.png "Angle") Ang, ![Vector4](Type-Vector4.png "Vector4") Color)

Index, Position, Scale, Angle, Color (RGBA)
Creates a new hologram entity (30 ops)

### ![Entity](Type-Entity.png "Entity") = holoCreate(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Position, ![Vector](Type-Vector.png "Vector") Scale, ![Angle](Type-Angle.png "Angle") Ang)

Index, Position, Scale, Angle
Creates a new hologram entity (30 ops)

### ![Entity](Type-Entity.png "Entity") = holoCreate(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Position, ![Vector](Type-Vector.png "Vector") Scale)

Index, Position, Scale
Creates a new hologram entity (30 ops)

### ![Entity](Type-Entity.png "Entity") = holoCreate(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Position)

Index, Position
Creates a new hologram entity (30 ops)

### ![Entity](Type-Entity.png "Entity") = holoCreate(![Number](Type-Number.png "Number") Index)

Index
Creates a new hologram entity (30 ops)

### holoDelete(![Number](Type-Number.png "Number") Index)

Removes a hologram (20 ops)

### holoDeleteAll()

Removes all holograms made by this E2 (20 ops)

### holoDeleteAll(![Number](Type-Number.png "Number") All)

 (20 ops)

### holoReset(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Model, ![Vector](Type-Vector.png "Vector") Scale, ![Vector](Type-Vector.png "Vector") Color, ![String](Type-String.png "String") Material)

Similar to holoCreate, but reusing the old entity (20 ops)

### ![Number](Type-Number.png "Number") = holoCanCreate()

Returns 1 when holoCreate() will successfully create a new hologram until the Max limit is reached
Replaces holoRemainingSpawns() (2 ops)

### ![Number](Type-Number.png "Number") = holoRemainingSpawns()

Returns how many holograms can be created this execution (2 ops)

### ![Number](Type-Number.png "Number") = holoAmount()

 (2 ops)

### ![Number](Type-Number.png "Number") = holoMaxAmount()

 (2 ops)

### holoScale(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Scale)

Sets the scale of the given hologram, as a multiplier (30 ops)

### ![Vector](Type-Vector.png "Vector") = holoScale(![Number](Type-Number.png "Number") Index)

Returns the scale of the given hologram (30 ops)

### holoScaleUnits(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Size)

Sets the scale of the given hologram, in source units (30 ops)

### ![Vector](Type-Vector.png "Vector") = holoScaleUnits(![Number](Type-Number.png "Number") Index)

Returns the scale of the given hologram in source units (30 ops)

### holoBoneScale(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Boneindex, ![Vector](Type-Vector.png "Vector") Scale)

Sets the scale of the given hologram bone, as a multiplier (30 ops)

### holoBoneScale(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Bone, ![Vector](Type-Vector.png "Vector") Scale)

Sets the scale of the given hologram named bone, as a multiplier (30 ops)

### ![Vector](Type-Vector.png "Vector") = holoBoneScale(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Boneindex)

Returns the scale of the given hologram bone (30 ops)

### ![Vector](Type-Vector.png "Vector") = holoBoneScale(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Bone)

Returns the scale of the given hologram named bone (30 ops)

### ![Vector](Type-Vector.png "Vector") = holoBonePos(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Boneindex)

Returns the position of the given hologram bone (30 ops)

### ![Vector](Type-Vector.png "Vector") = holoBonePos(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Bone)

Returns the position of the given hologram named bone (30 ops)

### ![Angle](Type-Angle.png "Angle") = holoBoneAng(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Boneindex)

Returns the angles of the given hologram bone (30 ops)

### ![Angle](Type-Angle.png "Angle") = holoBoneAng(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Bone)

Returns the angles of the given hologram named bone (30 ops)

### ![Number](Type-Number.png "Number") = holoClipsAvailable()

Returns the maximum number of clipping planes allowed per hologram (1 ops)

### holoClipEnabled(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Enabled)

Enables / disables clipping for a hologram with specified index (30 ops)

### holoClipEnabled(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Clipidx, ![Number](Type-Number.png "Number") Enabled)

Enables / disables clipping for a hologram with specified index. Clip index is for use with multiple clipping planes (30 ops)

### holoClip(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Origin, ![Vector](Type-Vector.png "Vector") Normal, ![Number](Type-Number.png "Number") Isglobal)

Defines a plane used to clip a hologram specified by it's position, direction and number 1/0 whether the position should be global or local to the hologram (30 ops)

### holoClip(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Clipidx, ![Vector](Type-Vector.png "Vector") Origin, ![Vector](Type-Vector.png "Vector") Normal, ![Number](Type-Number.png "Number") Isglobal)

Defines a plane used to clip a hologram specified by it's index, position, direction and number 1/0 whether the position should be global or local to the hologram (30 ops)

### holoClip(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Origin, ![Vector](Type-Vector.png "Vector") Normal, ![Entity](Type-Entity.png "Entity") Localent)

Defines a plane used to clip a hologram specified by it's position, and direction local to the given entity (30 ops)

### holoClip(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Clipidx, ![Vector](Type-Vector.png "Vector") Origin, ![Vector](Type-Vector.png "Vector") Normal, ![Entity](Type-Entity.png "Entity") Localent)

Defines a plane used to clip a hologram specified by it's index, position, and direction local to the given entity (30 ops)

### holoPos(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Position)

Sets the position of the hologram (15 ops)

### holoLocalPos(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Position)

Sets the local position of the hologram (15 ops)

### ![Vector](Type-Vector.png "Vector") = holoPos(![Number](Type-Number.png "Number") Index)

Gets the position of the hologram (15 ops)

### holoAng(![Number](Type-Number.png "Number") Index, ![Angle](Type-Angle.png "Angle") Ang)

Sets the angle of the hologram (15 ops)

### holoLocalAng(![Number](Type-Number.png "Number") Index, ![Angle](Type-Angle.png "Angle") Ang)

Sets the local angle of the hologram (15 ops)

### ![Angle](Type-Angle.png "Angle") = holoAng(![Number](Type-Number.png "Number") Index)

Gets the angle of the hologram (15 ops)

### holoColor(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Color)

Sets the color of the hologram (15 ops)

### holoColor(![Number](Type-Number.png "Number") Index, ![Vector4](Type-Vector4.png "Vector4") Color)

Sets the color and alpha of the hologram (15 ops)

### holoColor(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Color, ![Number](Type-Number.png "Number") Alpha)

Sets the color and alpha of the hologram (15 ops)

### holoAlpha(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Alpha)

Sets the transparency (0-255) of the hologram (15 ops)

### holoShadow(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Has_shadow)

Enables the hologram's shadow (10 ops)

### holoDisableShading(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Disable)

If 1, supresses engine lighting when drawing this hologram (10 ops)

### holoInvertModel(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Enable)

If not 0, inverts the model of the hologram (10 ops)

### ![Array](Type-Array.png "Array") = holoModelList()

Returns the list of valid models
See holoModelAny() (10 ops)

### ![Number](Type-Number.png "Number") = holoModelAny()

Returns 1 if models outside of holoModelList can be used.
Reads convar 'wire_holograms_modelany' (1 ops)

### holoModel(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Model)

Sets the model.
Must be from holoModelList unless wire_holograms_modelany is 1 (see holoModelAny()) (10 ops)

### holoModel(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Model, ![Number](Type-Number.png "Number") Skin)

Sets the model and skin.
Must be from holoModelList unless wire_holograms_modelany is 1 (see holoModelAny()) (10 ops)

### holoSkin(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Skin)

Changes the skin of a hologram (10 ops)

### holoMaterial(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Material)

Sets the overlay material of the hologram (10 ops)

### holoPlayerColor(![Number](Type-Number.png "Number") Index, ![Vector](Type-Vector.png "Vector") Color)

Sets the sub-color of a hologram with player model such as clothes or physgun (10 ops)

### holoRenderFX(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Effect)

Changes the RenderFX for a hologram (10 ops)

### holoBodygroup(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Bgrp_id, ![Number](Type-Number.png "Number") Bgrp_subid)

Index, Group ID, Group SubID
Sets the bodygroups of the given hologram (10 ops)

### ![Number](Type-Number.png "Number") = holoBodygroups(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Bgrp_id)

Index, Group ID
Returns the number of bodygroups in the Group ID of the given hologram (10 ops)

### holoVisible(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ply, ![Number](Type-Number.png "Number") Visible)

If 0, prevents a specific player from seeing the hologram (10 ops)

### holoVisible(![Number](Type-Number.png "Number") Index, ![Array](Type-Array.png "Array") Players, ![Number](Type-Number.png "Number") Visible)

If 0, prevents an array of players from seeing the hologram (10 ops)

### holoParent(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Otherindex)

Parents the hologram to another hologram (40 ops)

### holoParent(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent)

Parents the hologram to an entity (40 ops)

### holoParentAttachment(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent, ![String](Type-String.png "String") Attachmentname)

Parents the hologram to an entity's bone by its attachment name (40 ops)

### holoParentAttachment(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Otherindex, ![String](Type-String.png "String") Attachmentname)

Parents the hologram to another hologram's attachment by its attachment name (40 ops)

### holoParentBone(![Number](Type-Number.png "Number") Index, ![Entity](Type-Entity.png "Entity") Ent, ![Number](Type-Number.png "Number") Bone)

Parents the hologram to an entity's bone by its bone index. Note this is completely different from E2 (physics) bones (40 ops)

### holoParentBone(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Otherindex, ![Number](Type-Number.png "Number") Bone)

Parents the hologram to another hologram's bone by its bone index. Note this is completely different from E2 (physics) bones (40 ops)

### holoUnparent(![Number](Type-Number.png "Number") Index)

Un-parents the hologram (40 ops)

### holoBonemerge(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") State)

Enables bonemerge behavior on the hologram when the second argument is not 0 (10 ops)

### ![Entity](Type-Entity.png "Entity") = holoEntity(![Number](Type-Number.png "Number") Index)

Returns the entity corresponding to the hologram given by the specified index (2 ops)

### ![Number](Type-Number.png "Number") = holoIndex(![Entity](Type-Entity.png "Entity") Ent)

Returns the index of the given hologram entity (30 ops)

### holoAnim(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Animation)

Plays animation on the hologram specified by the index from frame 0 at the speed of 1 (15 ops)

### holoAnim(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Animation, ![Number](Type-Number.png "Number") Frame)

 (15 ops)

### holoAnim(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Animation, ![Number](Type-Number.png "Number") Frame, ![Number](Type-Number.png "Number") Rate)

Plays animation on the hologram specified by the index, the speed and starting point of which is determined by frame (ranging from 0 to 1) and rate (ranging from -12 to 12) values respectively (15 ops)

### holoAnim(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Animation)

Plays animation on the hologram specified by the index from frame 0 at the speed of 1 (15 ops)

### holoAnim(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Animation, ![Number](Type-Number.png "Number") Frame)

 (15 ops)

### ![Number](Type-Number.png "Number") = holoGetAnimFrame(![Number](Type-Number.png "Number") Index)

Returns the current frame of the playing animation (ranging from 0 to 1) on the index hologram (15 ops)

### holoAnim(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Animation, ![Number](Type-Number.png "Number") Frame, ![Number](Type-Number.png "Number") Rate)

Plays animation on the hologram specified by the index, the speed and starting point of which is determined by frame (ranging from 0 to 1) and rate (ranging from -12 to 12) values respectively (15 ops)

### ![Array](Type-Array.png "Array") = holoGetAnims(![Number](Type-Number.png "Number") Index)

Returns the number value of the animation string (15 ops)

### ![Number](Type-Number.png "Number") = holoAnimLength(![Number](Type-Number.png "Number") Index)

Returns the duration of the currently playing animation index hologram (15 ops)

### ![Number](Type-Number.png "Number") = holoAnimNum(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Animation)

Returns the number value of the animation string on the index hologram (15 ops)

### ![Number](Type-Number.png "Number") = holoGetAnimGroundSpeed(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Animation)

Returns the ground speed of the string animation on the index hologram (15 ops)

### holoSetAnimFrame(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Frame)

Sets the frame of the active animation of the index hologram (ranging from 0 to 1) (15 ops)

### holoSetAnimSpeed(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Rate)

Sets the active animation speed of the index hologram (ranging from -12 and 12) (15 ops)

### ![Number](Type-Number.png "Number") = holoGetAnimGroundSpeed(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Animation)

Returns the ground speed of the number animation on the index hologram (15 ops)

### holoSetPose(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Pose, ![Number](Type-Number.png "Number") Value)

Sets the string pose parameter on the index hologram by the number value, the range of which can be found with holoGetPoseRange() (15 ops)

### ![Number](Type-Number.png "Number") = holoGetPose(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Pose)

Returns the pose parameter specified by the string on the hologram specified by the index (15 ops)

### ![Array](Type-Array.png "Array") = holoGetPoses(![Number](Type-Number.png "Number") Index)

Returns all existing pose parameters on the hologram specified by the index (15 ops)

### ![Vector2](Type-Vector2.png "Vector2") = holoGetPoseRange(![Number](Type-Number.png "Number") Index, ![String](Type-String.png "String") Pose)

Returns the range of the pose parameter specified by the string on the hologram specified by the index (15 ops)

### holoClearPoses(![Number](Type-Number.png "Number") Index)

Sets all pose parameters of the hologram specified by the index to 0 (15 ops)
