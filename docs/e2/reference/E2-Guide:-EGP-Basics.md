<!--
Original author: Adosikas
Current maintainer: Denneisk
-->
- [Introduction](#introduction)
- 🟢 [Basic Usage](#basic-usage)
- 🟢 [Touchscreen](#touchscreen)
- 🟨 [Advanced Touchscreen](#advanced-touchscreen)
- 🟨 [Lists](#lists)
- 🟨 [Selection Menu](#selection-menu)

## Introduction
EGP is a screen for E2 that, unlike Digital Screens, doesn't work on the concept of drawing individual pixels. Instead individual objects, like boxes and text elements are used to define the content. EGPs are connected to the E2 via a `wirelink`. There are three different types of EGP.

* Screen<br>
This is a basic 512x512 pixel screen which is drawn on top of a prop. While the prop determines physical size and shape of the screen, it will always be 512x512 pixels, just scaled or stretched. As this is a physical screen, when someone uses the screen via the use key (default E), the `User` output will change to their entity. This can be used for simple "touchscreens". Due to the way it renders, certain materials, especially certain GUI materials, may not work on this type.

* Emitter<br>
In Render Target (RT) mode, this works like a screen except transparent and free floating.
While you do not have a `User` output, you can still use emitters to create touchscreens, but have to find out if someone points at your screen and presses E yourself (e.g., with `event keyPressed`).  
If you disable the render target mode, it still has the *main* 512x512 drawing area, but you can also draw outside of the bounds (however the display will only render if the main area is on screen). This mode will also allow you to use a few materials that were not available on the screen. However, by disabling the render target, the emitter is *completely* redrawn every frame, which may be detrimental to performance.

* HUD<br>
Objects added to HUD will draw directly on the HUD of everyone who is connected to the HUD by pressing the use key on it. Unlike the other types, the drawing area is the size of each players screen and matching the pixels. You can get the display size of a certain player via `egpScrSize(player)`, so you can scale objects to fit the screen of that player. However the positions of the objects will be the same for everyone that is connected to the HUD, so players with smaller monitors may not see objects if you place them near the bottom or right edge of your screen. Like the Non-RT Emitter, this has to redraw everything every frame.

### Objects
> [!NOTE]
> The index system is being phased out and replaced with the `egpobject` type, a direct link to an EGP object instead of the previous method. This is a lot more performant and allows for finer control over EGP objects.

By default EGP has 300 objects slots (numbered 1 through 300), or *indices*. Objects are drawn in the order they are *added* to the screen, unless you reorder them. The index does not affect order.

The objects are created and modified using functions such as `wirelink:egpBox(index, vector2 pos, vector2 size)` and `egpobject:setColor(vector color)`. EGP Objects are given their own special type returned by their "constructors", such as `egpBox` in the previous sentence. You should store these and use them whenever you can for speed and convenience. For every object, there is also a version for advanced users that takes a `table` as an input, such as `wirelink:egpBox(index, table args)`. This allows for directly setting up an object in one operation versus the old way of having to do things line-by-line. You can also use string indexing on EGP Objects to get and set their fields.

## Basic Usage
> 🟢 Easy

The following code demonstrates drawing to an EGP. This creates a red box at the center of the screen with a TextLayout, a text object that can be formatted, in the center of the box. Note the two different styles of initializing the EGP Objects—either method is valid; it's up to you which you prefer.
```golo
@name Colored Text
@inputs EGP:wirelink # wire this to the screen
@trigger none
@strict

function draw() {
    if(EGP) { # if EGP is valid
        EGP:egpClear() # Clear screen contents
    
        let Box = EGP:egpBox(1, vec2(256, 256), vec2(200, 50)) # Create a 200x50 box in the center of the screen, at index 1
        Box:setColor(vec(240, 60, 60)) # Color the object red using RGB values in a vector

        EGP:egpTextLayout(2, table( # Create a TextLayout object in the center of the screen, at index 2
            "text" = "Hello, World!",
            "x" = 256 - 100,
            "y" = 256 - 25,
            "w" = 200,
            "h" = 50,
            "font" = "Roboto",
            "size" = 30,
            "r" = 60, "g" = 240, "b" = 240, # Colors the text cyan
            "halign" = 1, "valign" = 1 # Centers the text in the TextLayout
        ))
    } else {
        print("No EGP wired! Please wire the wirelink to a EGP screen")
    }
}

draw() # Draw when E2 is spawned

event input(_:string) {
    draw() # Draw when input changes
}
```

## Touchscreen
> 🟢 Easy

As mentioned before, you can use the *User* output of EGP screens for simple touchscreens. This is a modified version of the previous example except this time using the *User* output of the EGP screen to demonstrate the touchscreen feature.

```golo
@name EGP Touchscreen
@inputs EGP:wirelink User:entity # Wire both of these to the EGP screen
@trigger none
@strict

function draw() {
    if(EGP) { # Same setup as above
        EGP:egpClear()
    
        EGPBox = EGP:egpBox(1, vec2(256, 256), vec2(200, 50)) # Note these are now globals
        EGPBox:setColor(vec(240, 60, 60))

        EGPText = EGP:egpTextLayout(2, table(
            "text" = "Press here",
            "x" = 256,
            "y" = 256,
            "w" = 200,
            "h" = 50,
            "font" = "Roboto",
            "size" = 16,
            "r" = 60, "g" = 240, "b" = 240,
            "halign" = 1, "valign" = 1
        ))
    } else {
        print("No EGP wired! Please wire the wirelink to a EGP screen")
    }
}

draw()

event input(Input:string) {
    if(Input == "User") { # E2 triggered by User input changing
        if(User) { # if User is valid
            # To arrive here, the User input must have changed, and is currently a valid entity (so someone used the screen)
            let CursorPos = EGP:egpCursor(User) # get the exact coordinates the user is pointing at, as a 2d vector
            if(EGPBox:containsPoint(CursorPos)) { # if the cursor coordinates are between the top-left and bottom-right corners of the box in BOTH x and y, the user is pointing inside the box
                EGPText:setText(User:name() + " clicked inside the box!") # Change text of the text object
            }
            else { # not inside => outside
              EGPText["text"] = User:name() + " clicked outside the box!" # We can also use array indexing to change the text
            }
        }
    } else {
        draw() # Redraw if the screen changed
    }
}
```

This example is sufficient for a few "buttons", but it might quickly get complicated as you add more buttons to the screen. Let's look below to try a different approach that's more flexible.

## Advanced Touchscreen
> 🟨 Intermediate

<!-- TODO Change this with some simple menu using callbacks -->
This example shows a simple game where you have multiple boxes that move randomly when someone clicks them. It is quite similar to the examples above, so refer to them for an explanation of the basics. The main difference is using a table here which allows you to to iterate over every box and perform a simple action if you click one.

```golo
@name Click Me If You Can
@inputs EGP:wirelink User:entity
@trigger none
@strict

function draw() {
    EGP:egpClear()
    
    let Text = EGP:egpTextLayout(1, "Click the boxes!", vec2(256, 16), vec2(256, 32)) # Create a text at the top border of the screen
    Text:setAlign(1, 0) # Change the alignment of the text, so the center-top of the text is aligned with the edge
    # that prevents the top half of the text being cut of by the edge of the screen
    # 0=align with left/top edge, 1=align with center, 2=align with right/bottom edge
    Text:setFont("Roboto", 30)

    # create three differently colored boxes in row
    let Box1 = EGP:egpBox(2, vec2(100, 256), vec2(100, 100))
    Box1:setColor(vec(240, 60, 60))
    let Box2 = EGP:egpBox(3, vec2(256, 256), vec2(100, 100))
    Box2:setColor(vec(60, 240, 60))
    let Box3 = EGP:egpBox(4, vec2(412, 256), vec2(100, 100))
    Box3:setColor(vec(60, 60, 240))
    
    Boxes = table(Box3, Box2, Box1) # In reverse order so the topmost box (3) is checked first
}

draw()

event input(Input:string) {
    if(Input == "User") {
        if(User) {
            local CursorPos = EGP:egpCursor(User)
      
            foreach(Number:number, Box:egpobject = Boxes) {# Loop over our 3 boxes
                if(Box:containsPoint(CursorPos)) { # Check if the user was pointing at a box
                    Box:setPos(randvec2(50, 462)) # Move the box anywhere with the drawing area
                    print(User:name() + " clicked on box " + (4 - Number))
                    break # Abort the loop, this makes sure only one box moves when you click on overlapping boxes
                }
            }
        }
    } else {
        draw()
    }
}
```

Since all our boxes do the same thing, we can keep the code very simple for them. Loops are your friend when creating complex EGPs, which will be demonstrated further in the next example.

## Lists
> 🟨 Intermediate

You can simplify setting up the position of items by dynamically assigning them using a bit of math. The following example creates a list of text boxes based on how many entries are in a table.

```golo
@name Typelist
@inputs EGP:wirelink
@trigger none
@strict

List = table(
    "Number: A plain number that can have fractions",
    "String: Series of text characters",
    "Vector: 3D Coordinates such as for a position",
    "Entity: Describes objects, such as Props or Players",
    "Wirelink: Used to interact with Wire objects, such as EGPs"
)

function draw() {
    EGP:egpClear()

    let HeaderBox = EGP:egpBox(1, vec2(256, 25), vec2(336, 40)) # width of 336 was chosen to match the text width roughly
    HeaderBox:setColor(vec(64)) # dark grey

    let HeaderText = EGP:egpText(2, "Some types E2 uses:", vec2(256, 25)) # using the center of the box as position
    HeaderText:setSize(36) # change the font size
    HeaderText:setAlign(1, 1) # align the text so it is centered horizontally and vertically

    let ID = 8
    
    foreach(I:number, Entry:string = List) { # do the following code for each Entry in the list (I is the index)
        
        let Pos = vec2(10, 32 + I * 50) # calculate position based on the index
        
        EGP:egpCircle(ID, Pos, vec2(4)) # draw a bullet point/circle
        
        ID++ # Increment ID every time we make an object
        
        let Text = EGP:egpText(ID, Entry, Pos + vec2(12, 0)) # Draw the text a bit right of the point
        Text:setSize(20)
        Text:setAlign(0, 1) # align the text so it is aligned left and centered vertically
        
        ID++
    }
}

draw()

event input(_:string) { reset() }

```
Note how *Pos* is mathematically derived. This is a lot better than having to manually specify, for example, an array of positions. And since it's formulaic, you can just tweak the numbers until it looks right without having to do everything manually.

While this is just a very basic example, here are a few ideas you could try yourself:
- Adjust the spacing between entries
- Create more than 2 elements per entry (maybe a background?).
- Replace the string with a table that contains multiple values, such as a string and color to have colored text, or string and number for a price list
- Use a dynamic list instead of a hard coded one
  - Make a list and use [[E2: Chat Commands]] to modify it
  - Iterate over every player and display their names and health, and use timers to update it periodically.<br>
    Bonus: Display their Rank/Team in the matching color using the `team` functions.

## Selection Menu
> 🟨 Intermediate

Wrapping together all this knowledge, let's create a list that's interactive and dynamically generated. This example creates a list of some E2 types and, when pressed on, shows some details about them. Note how we use a box that contains every other button to first check if we should even consider those buttons. This is called *[bounding volume hierarchy](https://en.wikipedia.org/wiki/Bounding_volume_hierarchy)* and is an extremely useful optimization trick for more than just EGP. Some more optimizations tricks are used here, such as guessing which button might be pressed.

```golo
@name Interactive Typelist
@inputs EGP:wirelink User:entity
@persist List:table ListStart:vector2 ListEnd:vector2 ListSpacing CurrentlySelected:egpobject
@persist ContentText:egpobject
@trigger none
@strict

# Using a table with a table for each entry, containing name and info
List = table(
    table("Number"  , "A plain number that can have fractions"),
    table("String"  , "Series of text characters"),
    table("Vector"  , "3D Coordinates such as for a position"),
    table("Entity"  , "Describes objects, such as Props or Players"),
    table("Wirelink", "Used to interact with Wire objects, such as EGPs")
)

function draw() {
    EGP:egpClear()
    
    let Header = EGP:egpBox(1, vec2(256,25), vec2(486, 40))
    Header:setColor(vec(64,64,64))

    let HeadText = EGP:egpText(2, "Select a type to display info:", vec2(256, 25))
    HeadText["size"] = 36
    HeadText:setAlign(1, 1)

    CurrentlySelected = noegpobject() # none

    # Settings for our list
    let Start = vec2(256, 80) # position of the first box
    let BoxSize = vec2(100, 40) # size of each box
    ListSpacing = 60 # offset between center of two entries
    
    let Length = (List:ncount() + 1) * ListSpacing
    
    # Set the start and end positions of the interactable area
    let HalfBox = BoxSize / 2
    ListStart = Start - HalfBox
    ListEnd = Start + vec2(0, Length) + HalfBox
    
    let ID = 8
    
    foreach(I:number, Table:table = List) { # loop over the list
        let Name = Table[1, string] # get the name from the entry data with our index
        let Pos = Start + vec2(0, (I - 1) * ListSpacing) # calculate vertical offset based on index-1 (so the first box is at the start pos)
        
        let Box = EGP:egpBox(ID, Pos, BoxSize) # grey background
        Box:setColor(vec(127))
        
        Table[3] = Box # Store the egpobject to reference later
        
        ID++ # Increment ID every time we make an object
        
        let Text = EGP:egpTextLayout(ID, Name, Pos, BoxSize)
        Text["size"] = 28
        Text:setAlign(1, 1)
        
        ID++
    }
    
    # Simply use the next indices for these, too
    
    let Tall = 512 - Length - 16
    let ContentBox = EGP:egpBox(ID, vec2(256, Length + Tall / 2), vec2(486, Tall))
    ContentBox:setColor(32, 32, 32, 255)
    
    ID++
    
    ContentText = EGP:egpTextLayout(ID, "", vec2(256, Length + Tall / 2), vec2(486, Tall))
    ContentText["halign"] = 1 # Set horizontal align to center
    ContentText["size"] = 28
    
}

draw()

event input(Input:string) {
    if(Input == "User") {
        if(User) {
            let Cursor = EGP:egpCursor(User)
            # check if the position is roughly in the area occupied by the list
            if (inrange(Cursor, ListStart, ListEnd)) {
                let VerticalPositionInListArea = Cursor:y() - ListStart:y()
                let ClosestListEntry = floor(VerticalPositionInListArea / ListSpacing) + 1 # just divide the vertical pos by the spacing to get which button we are closest to
                let Target = List[ClosestListEntry, table]
                let Object = Target[3, egpobject]
                
                if(Object:containsPoint(Cursor)) { # check if the cursor is inside that button
                    # button was pressed, first update the outputs
                    let CurrentEntry = List[ClosestListEntry, table]
                    ContentText:setText(CurrentEntry[2, string])
                
                    if (CurrentlySelected) { # if something was previously selected
                        CurrentlySelected:setColor(vec(127)) # reset color of that entry
                    }
                    Object:setColor(vec(64, 127, 64)) # change color of now selected entry
                    CurrentlySelected = Object
                }
            } else { # User pressed outside, clear the selection
                if (CurrentlySelected) {
                    CurrentlySelected:setColor(vec(127))
                }
                CurrentlySelected = noegpobject()
                
                ContentText:setText(" ")
            }
        }
    } else {
        draw()
    }
}

```
This could easily be expanded into a simple shop or choosing the destination of a teleporter or elevator. To do this you could just replace the info-string with a price, or a location, or whatever you choose.  

Here's some ideas you could try out to on your own:
- Make a 2D grid instead of a 1D list. Hint: Most math, including division and rounding works just as well on 2d-vectors
- Allow a longer list by adding scroll/page switch buttons, by making the for loop start and end based on variables
- Use more complicated entries. You could for example add buttons left and right of each entry to decrease/increase prices of that item. Hint: You can reuse most of the calculation, no need to calculate `ClosestListEntry` multiple times, just add another inrange.
- Use [function lambdas](/wiremod/wire/wiki/E2-Guide:-Lambdas) to create a unique effect for every button.