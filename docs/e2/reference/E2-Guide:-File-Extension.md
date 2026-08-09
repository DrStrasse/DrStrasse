The *file* extension allows you to create, read, and modify files locally stored on your computer. Because files are stored locally by you, this means they must be sent to the server using `fileLoad` before they can be accessed. Files cannot be modified without a similar network transaction back using `fileWrite`. *file* also contains `fileList` to query what files exist in a directory.

#### File locations
Files are by default saved into `e2files` in your Garry's Mod *data* directory, but can also be redirected using `>` into these select directories:
- `>e2files` -> `e2files`
- `>e2shared` -> `expression2/e2shared`
- `>cpushared` -> `cpuchip/e2shared`
- `>gpushared` -> `gpuchip/e2shared`
- `>spushared` -> `spuchip/e2shared`

An example usage would be `fileWrite(">e2shared/test.txt", "Hello, World!")`, which would then write a file which you could access in the Expression 2 file browser under `e2shared`.

> [!IMPORTANT]
> It is impossible in Garry's Mod to write to a file outside of the `garrysmod/data` folder.
> On top of this, the *file* extension can only read and write to the above directories. The extension **cannot** read files from the server.

#### Requirements of a file
Files can fail to load, create, or otherwise fail if these rules are not followed;

1. Filename must end with `.txt`
2. File must be inside one of the [above directories](#file-locations)
3. Files must be under the size limit (default 300KiB)

## Basic File Operations
> [!WARNING]
> The examples here *will* write files to your `e2files` directory. Make sure you're not overwriting anything important before trying these!

To show what a typical usage of file operations looks like, let's try writing to a file on the chip start and reading it back after it's written. `fileWrite(string path, string data)` allows you to write to a file. If the file exists, it will be overwritten. There are *no* safeguards for file overwriting, so make sure you're not replacing important data when doing this!

```ruby
@name File Write and Read
@trigger none
@strict

fileWrite("test.txt", "Hello, World! " + curtime())
```

Just to show that the file we're writing is being overwritten, we'll also add `curtime()` to the end of its message, which will give it a "timestamp" every time this code is ran. Next, we'll add events to read the file once it finishes writing. We can use the event `fileWritten`, which triggers right after a file finishes writing. The first parameter of `fileWritten` is the path of the written file. We'll use that here to demonstrate its usage. The second parameter is the data that we just wrote, which we'll discard in this example. We'll then use `fileLoad` on this path, which will load up `test.txt` and trigger the `fileLoaded` event when finished.

```ruby
event fileWritten(Path:string, _:string) {
    fileLoad(Path)
}
```

In the `fileLoaded` event, the first parameter is the path to the file as a string, and the second is the contents of the file, also as a string. We'll just print out both with some simple formatting. We'll also print out `curtime()` to see how much time has progressed between writing and loading.

```ruby
event fileLoaded(Path:string, Data:string) {
    print(format("%s: %s \nTime: %f", Path, Data, curtime()))
}
```

After running our code, we should see an output like this:
```
test.txt: Hello, World! 6030.6748046875 
Time: 6031.094727
```

<details><summary>Full example code</summary>

```ruby
@name File Write and Read
@trigger none
@strict

fileWrite("test.txt", "Hello, World! " + curtime())

event fileWritten(Path:string, _:string) {
    fileLoad(Path)
}

event fileLoaded(Path:string, Data:string) {
    print(format("%s: %s \nTime: %f", Path, Data, curtime()))
}
```
</details>

## File queuing
> [!IMPORTANT]
> These examples contain E2 functions that are only available on the Github release currently

> [!WARNING]
> The examples here *will* write files to your `e2files` directory. Make sure you're not overwriting anything important before trying these!

You can queue multiple file operations at once and they will be processed sequentially. By default, you can queue 5 operations of loading, writing, and listing each. Exceeding the limit will throw a runtime error. To demonstrate the queue, let's try creating a lot of files, listing them, and then opening them all.

We'll start by programmatically creating all the files in a directory for this example. We'll name the files as `manyfiles/<number>.txt` and contain a simple generic message. We'll also use `fileCanWrite` to see if we can still write files, and break early if we can't.

```ruby
@name File Queues
@persist List:array
@trigger none
@strict

for(I = 1, 10) {
    if(fileCanWrite()) {
        fileWrite(format("manyfiles/%d.txt", I), format("This is file #%d!", I))
    } else { break }
}
```

With that out of the way, let's get onto the events. The first one we'll register is the `fileWritten` event. We'll use this to make sure we're done writing everything before listing. We can ignore the parameters for this and instead use `fileWriteQueued()`, which returns the number of elements in the corresponding queue. We'll check if it's 0 to confirm the queue is empty, and then use `fileList` on `"manyfiles/"` to get all the files inside that directory. Note that the slash is mandatory.

```ruby
event fileWritten(_:string, _:string) {
    if(fileWriteQueued() == 0) {
        fileList("manyfiles/")
    }
}
```

After that, we'll register the `fileList` event, which triggers when a list is received. Like files, lists are also networked, so they don't happen instantly. The first parameter is the directory path. The second parameter is an array of strings of all the files and subdirectories in the directory. We'll loop over this array and read each file inside the directory, making sure to not run into any queue errors. Note that the filenames in the array are relative, so we'll concatenate them to the directory path to get the full path.

Note that we naively assume there are no subdirectories here.

```ruby
event fileList(Path:string, Contents:array) {
    foreach(_:number, Name:string = Contents) {
        if(fileCanLoad()) {
            fileLoad(Path + Name)
        } else { break }
    }
}
```

Finally, we'll copy the code in the previous example using event `fileLoaded` to print the contents of the file and its path, except modified to not include time.

```ruby
event fileLoaded(Path:string, Data:string) {
    print(format("%s: %s", Path, Data))
}
```

After running our code, you should see an output like this:
```
manyfiles/1.txt: This is file #1!
manyfiles/2.txt: This is file #2!
manyfiles/3.txt: This is file #3!
manyfiles/4.txt: This is file #4!
manyfiles/5.txt: This is file #5!
```

Note that the queue is *not* asynchronous, so the queue will always execute in the order that you loaded files.

<details><summary>Full example code</summary>

```ruby
@name File Queues
@trigger none
@strict

for(I = 1, 10) {
    if(fileCanWrite()) {
        fileWrite(format("manyfiles/%d.txt", I), format("This is file #%d!", I))
    } else { break }
}

event fileWritten(_:string, _:string) {
    if(fileWriteQueued() == 0) {
        fileList("manyfiles/")
    }
}

event fileList(Path:string, Contents:array) {
    foreach(_:number, Name:string = Contents) {
        if(fileCanLoad()) {
            fileLoad(Path + Name)
        } else { break }
    }
}

event fileLoaded(Path:string, Data:string) {
    print(format("%s: %s", Path, Data))
}
```
</details>