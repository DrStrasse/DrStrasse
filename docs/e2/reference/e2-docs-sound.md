[Jump to table of contents](#default-extensions)

# Sound

### soundPlay(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Duration, ![String](Type-String.png "String") Path)

Plays sound from the E2 chip. soundPlay(string Index, number Duration, string Path to File) (25 ops)

### soundPlay(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Duration, ![String](Type-String.png "String") Path)

Plays sound from the E2 chip. soundPlay(int Index, number Duration, string Path to File) (25 ops)

### ![Entity](Type-Entity.png "Entity"):soundPlay(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Duration, ![String](Type-String.png "String") Path)

Plays sound from an entity. soundPlay(string Index, number Duration, string Path to File) (25 ops)

### ![Entity](Type-Entity.png "Entity"):soundPlay(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Duration, ![String](Type-String.png "String") Path)

Plays sound from an entity. soundPlay(int Index, number Duration, string Path to File) (25 ops)

### soundPlay(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Duration, ![String](Type-String.png "String") Path, ![Number](Type-Number.png "Number") Fade)

Plays sound from the E2 chip. soundPlay(string Index, number Duration, string Path to File, number FadeTime) (25 ops)

### soundPlay(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Duration, ![String](Type-String.png "String") Path, ![Number](Type-Number.png "Number") Fade)

Plays sound from the E2 chip. soundPlay(int Index, number Duration, string Path to File, number FadeTime) (25 ops)

### ![Entity](Type-Entity.png "Entity"):soundPlay(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Duration, ![String](Type-String.png "String") Path, ![Number](Type-Number.png "Number") Fade)

Plays sound from an entity. soundPlay(int Index, number Duration, string Path to File, number FadeTime) (25 ops)

### ![Entity](Type-Entity.png "Entity"):soundPlay(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Duration, ![String](Type-String.png "String") Path, ![Number](Type-Number.png "Number") Fade)

Plays sound from an entity. soundPlay(string Index, number Duration, string Path to File, number FadeTime) (25 ops)

### soundStop(![String](Type-String.png "String") Index)

Stops the sound stored at the string index and removes the entry (5 ops)

### soundStop(![Number](Type-Number.png "Number") Index)

Stops the sound stored at the integer index and removes the entry (5 ops)

### soundStop(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Fadetime)

Fades the sound stored at the first input's integer index in the second input's amount of seconds and removes the entry (5 ops)

### soundStop(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Fadetime)

Fades the sound stored at the string index in the integer input's amount of seconds and removes the entry (5 ops)

### soundVolume(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Volume)

soundVolume(string Index, Volume), where Volume is a number between 0 and 1. Default Volume is 1 (5 ops)

### soundVolume(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Volume)

soundVolume(integer Index, Volume), where Volume is a number between 0 and 1. Default Volume is 1 (5 ops)

### soundVolume(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Volume, ![Number](Type-Number.png "Number") Fadetime)

soundVolume(string Index, Volume, FadeTime), where Volume is a number between 0 and 1. Default Volume is 1 (5 ops)

### soundVolume(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Volume, ![Number](Type-Number.png "Number") Fadetime)

soundVolume(integer Index, Volume, FadeTime), where Volume is a number between 0 and 1. Default Volume is 1 (5 ops)

### soundPitch(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Pitch)

soundPitch(integer Index, number Pitch) Default Pitch is 100, max is 255. Pitch is scaled linearly (like frequency), rather than by octave (5 ops)

### soundPitch(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Pitch)

soundPitch(string Index, number Pitch) Default Pitch is 100, max is 255. Pitch is scaled linearly (like frequency), rather than by octave (5 ops)

### soundPitch(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Pitch, ![Number](Type-Number.png "Number") Fadetime)

soundPitch(integer Index, number Pitch, number Fadetime) Default Pitch is 100, max is 255. Pitch is scaled linearly (like frequency), rather than by octave (5 ops)

### soundPitch(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Pitch, ![Number](Type-Number.png "Number") Fadetime)

soundPitch(string Index, number Pitch, number Fadetime) Default Pitch is 100, max is 255. Pitch is scaled linearly (like frequency), rather than by octave (5 ops)

### soundPurge()

Clears the sound table and stops all sounds (5 ops)

### ![Number](Type-Number.png "Number") = soundDuration(![String](Type-String.png "String") Sound)

soundDuration(string Path to File) Returns the duration of the sound. Note: If the server hasn't the file it returns 60 (5000 ops)

### soundDSP(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Dsp)

Sets the DSP effect for the sound at the index, then restarts the sound (5 ops)

### soundDSP(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Dsp)

Sets the DSP effect for the sound at the index, then restarts the sound (5 ops)

### soundLevel(![String](Type-String.png "String") Index, ![Number](Type-Number.png "Number") Level)

Sets the sound's level in dB, then restarts the sound. This affects how far away the sound can be heard. (5 ops)

### soundLevel(![Number](Type-Number.png "Number") Index, ![Number](Type-Number.png "Number") Level)

Sets the sound's level in dB, then restarts the sound. This affects how far away the sound can be heard. (5 ops)

### ![Number](Type-Number.png "Number") = soundDSP(![Number](Type-Number.png "Number") Index)

Returns the DSP effect for the sound at the index (default 0) (2 ops)

### ![Number](Type-Number.png "Number") = soundDSP(![String](Type-String.png "String") Index)

Returns the DSP effect for the sound at the index (default 0) (2 ops)

### ![Number](Type-Number.png "Number") = soundLevel(![String](Type-String.png "String") Index)

Returns the sound level in dB for the sound at the index (2 ops)

### ![Number](Type-Number.png "Number") = soundLevel(![Number](Type-Number.png "Number") Index)

Returns the sound level in dB for the sound at the index (2 ops)

### ![Number](Type-Number.png "Number") = soundPitch(![Number](Type-Number.png "Number") Index)

Returns the pitch of the sound at the index (2 ops)

### ![Number](Type-Number.png "Number") = soundPitch(![String](Type-String.png "String") Index)

Returns the pitch of the sound at the index (2 ops)

### ![Number](Type-Number.png "Number") = soundVolume(![Number](Type-Number.png "Number") Index)

Returns the volume of the sound at the index (2 ops)

### ![Number](Type-Number.png "Number") = soundVolume(![String](Type-String.png "String") Index)

Returns the volume of the sound at the index (2 ops)

### ![Number](Type-Number.png "Number") = soundPlaying(![Number](Type-Number.png "Number") Index)

Returns 1 if the sound at the index is playing, 0 if not (2 ops)

### ![Number](Type-Number.png "Number") = soundPlaying(![String](Type-String.png "String") Index)

Returns 1 if the sound at the index is playing, 0 if not (2 ops)

### ![Entity](Type-Entity.png "Entity"):emitSound(![String](Type-String.png "String") Soundname, ![Number](Type-Number.png "Number") Soundlevel, ![Number](Type-Number.png "Number") Pitchpercent, ![Number](Type-Number.png "Number") Volume)

Plays sound on entity. Note that one file can only be played once in a time. (20 ops)

### ![Entity](Type-Entity.png "Entity"):emitSound(![String](Type-String.png "String") Soundname, ![Number](Type-Number.png "Number") Soundlevel, ![Number](Type-Number.png "Number") Pitchpercent)

Plays sound on entity. Note that one file can only be played once in a time. (20 ops)

### ![Entity](Type-Entity.png "Entity"):emitSound(![String](Type-String.png "String") Soundname, ![Number](Type-Number.png "Number") Soundlevel)

Plays sound on entity. Note that one file can only be played once in a time. (20 ops)

### ![Entity](Type-Entity.png "Entity"):emitSound(![String](Type-String.png "String") Soundname)

Plays sound on entity. Note that one file can only be played once in a time. (20 ops)

### ![Entity](Type-Entity.png "Entity"):emitSoundStop(![String](Type-String.png "String") Soundname)

Stops sound played with 'emitSound' (20 ops)
