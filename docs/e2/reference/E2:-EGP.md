# Intro
EGP is a screen for E2 that unlike Digital Screens doesn't work on the concept of drawing individual pixels. Instead individual objects, like boxes and text elements are used to define the content. See the next section for more information about those objects.  
EGPs are connected to the E2 via a wirelink. There are three different types of EGP:

* Screen  
This is a basic 512x512 pixel screen which is drawn on top of a prop. While the prop determines physical size and shape of the screen, it will always be 512x512 pixels, just scaled or stretched. As this is a physical screen, when someone uses the screen via the use key (default E), the `User` output will change to their entity. This can be used for simple "touchscreens".  
However, due to the way it renders, certain materials, especially certain gui materials, may not work on this type.

* Emitter  
In RenderTarget (RT) mode, this works like a screen except transparent and free floating.
While you do not have a `User` output, you can still use emitters to create touchscreens, but have to find out if someone points at your screen and presses E yourself (ie via `runOnKey`).  
If you disable the render target mode, it still has the *main* 512x512 drawing area, but you can also draw outside of the bounds (however the display will only render if the main area is on screen). This mode will also allow you to use a few materials that were not available on the screen. However, by disabling the render target, the emitter is *completely* redrawn every frame, which may be detrimental to performance.

* HUD  
Objects added to HUD will draw directly on the HUD of everyone who is connected to the HUD by pressing the use key on it. Unlike the other types, the drawing area is the size of each players screen and matching the pixels. You can get the display size of a certain player via `egpScrSize(player)`, so you can scale objects to fit the screen of that player. However the positions of the objects will be the same for everyone that is connected to the HUD, so players with smaller monitors may not see objects if you place them near the bottom or right edge of your screen. Like the Non-RT Emitter, this has to redraw everything every frame.

# Objects
By default EGP has 300 objects slots (numbered 1 through 300). Objects are drawn in the order they are *added* to the screen, unless you reorder them, the ID does not affect order.

The objects are created and modified using functions such as `wirelink:egpBox(id, pos, size)` and `wirelink:egpColor(id, color)`. `wirelink` is a wirelink to the EGP screen, and `id` is the slot id as mentioned above. The object creation functions only take the required parameters, such as position, size or text to display, everything else has to be changed via the appropriate function, but you can also modify the required parameters in the same way.

# Simple example
```golo
@name Colored Text
@inputs EGP:wirelink # wire this to the screen
if(first() | ~EGP) { # E2 triggered by spawning the E2 or changing the EGP input
  if(->EGP) { # EGP is wired to something
    EGP:egpClear() # Clear screen contents
    
    EGP:egpBox(1, vec2(256, 256), vec2(200, 50)) # create a 200x50 box in the center of the screen, stored in slot 1
    EGP:egpColor(1, vec(240, 60, 60)) # color the object in slot 1 (that box) red (decimal RGB values in a vector)

    EGP:egpText(2, "Hello World", vec2(256, 256)) # create a Hello World text object in the center of the screen, stored in slot 2
    EGP:egpFont(2, "Roboto", 30) # Set font and font size for that text
    EGP:egpColor(2, vec(60, 240, 240)) # Color the text cyan
  }
  else {
    print("No EGP wired! Please wire the wirelink to a EGP screen")
  }
}
```

# Touchscreen

As mentioned above, you can use the `User` output of EGP screens for simple touchscreens. Here we just record the players name and if he clicked inside the box

```golo
@name EGP Touchscreen
@inputs EGP:wirelink User:entity # wire both of these to the EGP screen
if(first() | ~EGP) { # E2 triggered by spawning the E2 or changing the EGP input
  if(->EGP) { # EGP is wired to something

    EGP:egpClear() # Clear screen contents
    
    EGP:egpBox(1, vec2(256, 256), vec2(200, 50)) # create a 200x50 box in the center of the screen, stored in slot 1
    EGP:egpColor(1, vec(240, 60, 60)) # color the object in slot 1 (that box) red (decimal RGB values in a vector)

    EGP:egpText(2, "Press here", vec2(256, 256)) # create a text object in the center of the screen, stored in slot 2
    EGP:egpFont(2, "Roboto", 30) # Set font and font size for that text
    EGP:egpColor(2, vec(60, 240, 240)) # Color the text cyan
  }
  else {
    print("No EGP wired! Please wire the wirelink to a EGP screen")
  }
}
elseif(~User){ # E2 triggered by User input changing
  if(User){ # If User is currently set to a valid entity
    # To arrive here, the User input must have changed, and is currently a valid entity (so someone used the screen)
    local CursorPos = EGP:egpCursor(User) # get the exact coordinates the user is pointing at, as a 2d vector
    local TopLeft = vec2(256-100, 256-25) # top left corner of the box is center - size/2
    local BotRight = vec2(256+100, 256+25) # bottom right corner of the box is center + size/2
    if(inrange(CursorPos, TopLeft, BotRight)) { # if the cursor coordinates are between the top-left and bottom-right corners of the box in BOTH x and y, the user is pointing inside the box
      EGP:egpSetText(2, User:name()+" clicked inside the box!") # Change text of the text object
    }
    else { # not inside => outside
      EGP:egpSetText(2, User:name()+" clicked outside the box!")
    }
  }
}
```

Now you might look at this and say "That is super complicated! If I do that for 5 Boxes my code gets super long and i have to change the position and size of the box in multple places!". And you are right. This is just a simple example to explain the concept of touchscreens. Read below for a more flexible way.

# Advanced Touchscreen

This is a simple game where you get multiple boxes that move randomly when someone clicks them. It is quite similar to the examples above, so refer to them for an explanation of the basics.

```golo
@name Click Me If You Can
@inputs EGP:wirelink User:entity
if( (first() | ~EGP) & ->EGP ) { # Combining both ifs into one
  function number cursorInBox(Cur:vector2, ID) { # helper function to check if the cursor is inside that box
    # note that this function only works reliably on boxes and does not support rotation
    # it also is fairly inefficent since it calculates the positions dynamically, which is helpful in this example
    # because the boxes are moving and there are just a few, but for a proper E2 you want to use something more efficent
    local Pos = EGP:egpGlobalPos(ID) # retrieve current center of the box, accounting for parenting
    local Size = EGP:egpSize(ID) # retrieve current size of the box
    return inrange(Cursor, Pos-Size/2, Pos+Size/2) # see above example for the reasoning behind this
  }
  EGP:egpClear()
  EGP:egpText(1, "Click the boxes!", vec2(256, 0)) # Create a text at the top border of the screen
  EGP:egpAlign(1, 1, 0) # Change the alignment of the text, so the center-top of the text is aligned with the edge
    # that prevents the top half of the text being cut of by the edge of the screen
    # 0=align with left/top edge, 1=align with center, 2=align with right/bottom edge
  EGP:egpFont(1, "Roboto", 30)

  # create three differently colored boxes in row
  EGP:egpBox(2, vec2(100, 256), vec2(100, 100))
  EGP:egpColor(2, vec(240, 60, 60))
  EGP:egpBox(3, vec2(256, 256), vec2(100, 100))
  EGP:egpColor(3, vec(60, 240, 60))
  EGP:egpBox(4, vec2(412, 256), vec2(100, 100))
  EGP:egpColor(4, vec(60, 60, 240))
}
elseif(~User&User){ # Again combining ifs
  local CursorPos = EGP:egpCursor(User)
  
  for(I=4, 2, -1){ # Loop over our 3 boxes starting from the last (and topmost in the drawing order)
    if(cursorInBox(CursorPos, I)) { # Use our custom function to check if the user was pointing at that box
      EGP:egpPos(I, randvec2(50,462)) # Move the box anywhere with the drawing area (leaving half the size of space at the edges so the whole box is always visible)
      print(User:name()+" clicked on box "+I)
      break # Abort the loop, this makes sure only one box moves when you click on overlapping boxes
    }
  }
}
```

See how I just used a loop to check all boxes (without creating a if for every single one), because they all do the same thing anyway? Loops are your friend when creating complex EGPs, which will be demonstrated further in the next example.  
But often you want buttons that do almost the same thing but with different values. See [Selection Menu](#selection-menu) for that.

# Lists

If you have lots of similar objects, you can just store the changing values in a array or table and calculate the position so they are spaced nice and even.

```golo
@name Typelist
@inputs EGP:wirelink
if( (first() | ~EGP) & ->EGP ) { # Combining both ifs into one
  EGP:egpClear()

  local List = table(
    "Number: Just a plain number with decimals",
    "String: Bit of text",
    "Vector: 3D Coordinates ie for a position",
    "Entity: Describes objects, ie Props or Players",
    "Wirelink: Used to interact with Wire objects, ie EGPs")

  EGP:egpBox(1, vec2(256,25), vec2(300, 40)) # width of 300 was chosen to match the text width roughly
  EGP:egpColor(1, vec(64,64,64)) # dark grey

  EGP:egpText(2, "Some types E2 uses:", vec2(256, 25)) # using the center of the box as position
  EGP:egpSize(2, 40) # change the font size
  EGP:egpAlign(2, 1, 1) # align the text so it is centered horizontally and vertically

  foreach(I:number, Entry:string = List) { # do the following code for each Entry in the list (I is the index)
    local CurrentID = I*2 + 8 # the first Entry (I=1) will have index 10 (and 11)
    local CurrentPos = vec2(10, 32 + I*50) # calculate position based on the index
    
    EGP:egpCircle(CurrentID, CurrentPos, vec2(4,4)) # draw a bullet point/circle
    
    EGP:egpText(CurrentID+1, Entry, CurrentPos+vec2(12, 0)) # Draw the text a bit right of the point
    EGP:egpSize(CurrentID+1, 28)
    EGP:egpAlign(CurrentID+1, 0, 1) # align the text so it is aligned left and centered vertically
  }
}
```
Another part I want to highlight here is how we calculate `CurrentPos` based on the index. Sure we could have made a second array of hand-picked or manually calculated positions, but that gets tedious. And with the formula you can just tweak it until it looks "right" without having to update every single position.

While this is just a very basic example, here are a few ideas you could try yourself:

* Adjust the spacing between entries
* Create more than 2 elements per entry (maybe a background?). Hint: Adjust the `CurrentID` calculation to have more slots for each
* Replace the string with a table that contains multiple values, ie string+color to have colored text, or string+number for a price list
* Use a dynamic list instead of a hard coded one
  * Make a `@persist`ed list and use [[E2: Chat Commands]] to modify it (also re-draw to update the egp)
  * Use `foreach(N, Player:entity = players())` and display the players name and health, and use timers to update it periodically.  
Bonus: Display their Rank/Team in the matching color using the `team` functions ( check E2Helper)

# Selection Menu

This example creates a interactive list of buttons to select output values.

```golo

@name Interactive Typelist
@inputs EGP:wirelink User:entity
@outputs Type:string Info:string
@persist List:table ListStart:vector2 BoxSize:vector2 ListSpacing CurrentlySelected
if ( (first() | ~EGP) & ->EGP ) { # Combining both ifs into one
  EGP:egpClear()

  # Now using a table with a table for each entry, containing name and info
  List = table(
    table("name"="Number"  , "info"="Just a plain number with decimals"),
    table("name"="String"  , "info"="Bit of text"),
    table("name"="Vector"  , "info"="3D Coordinates ie for a position"),
    table("name"="Entity"  , "info"="Describes objects, ie Props or Players"),
    table("name"="Wirelink", "info"="Used to interact with Wire objects, ie EGPs")
  )

  EGP:egpBox(1, vec2(256,25), vec2(380, 40))
  EGP:egpColor(1, vec(64,64,64))

  EGP:egpText(2, "Select a type to output info:", vec2(256, 25))
  EGP:egpSize(2, 40) 
  EGP:egpAlign(2, 1, 1)

  CurrentlySelected=0 # none

  # settings for our list, we use those later to detect clicks
  ListStart = vec2(256, 100) # position of the first box
  BoxSize = vec2(100,40) # size of each box
  ListSpacing = 80 # offset between center of two entries

  for (I=1, List:count()) { # loop over the list
    local CurrentEntryName = List[I, table]["name", string] # get the name from the entry data with our index
    local CurrentID = 8 + I*2 # the first Entry (I=1) will have index 10 for the box (and 11 for the text)
    local CurrentPos = ListStart + vec2(0, (I-1)*ListSpacing) # calculate vertical offset based on index-1 (so the first box is at the start pos
    
    EGP:egpBox(CurrentID, CurrentPos, BoxSize) # grey background
    EGP:egpColor(CurrentID, vec(127))
    
    EGP:egpText(CurrentID+1, CurrentEntryName, CurrentPos)
    EGP:egpSize(CurrentID+1, 28)
    EGP:egpAlign(CurrentID+1, 1, 1)
  }
}
elseif (~User & User) {
  local Cursor = EGP:egpCursor(User)
  # check if the position is roughly in the area occupied by the list
  if (inrange(Cursor, ListStart-BoxSize/2, # top left corner of first box
                     ListStart+vec2(0,ListSpacing*(List:count()-1))+BoxSize/2)) { # bottom right corner of the last box
    local VerticalPositionInListArea = Cursor:y()-ListStart:y()
    local ClosestListEntry = round(VerticalPositionInListArea/ListSpacing)+1 # just divide the vertical pos by the spacing to get which button we are closest to
    local RelativePosition = Cursor-(ListStart+vec2(0, (ClosestListEntry-1)*ListSpacing)) # get the position relative to the closest button
    
    if (inrange(RelativePosition, -BoxSize/2, BoxSize/2)) { # check if the cursor is inside that button
      # button was pressed, first update the outputs
      local CurrentEntry = List[ClosestListEntry, table] # add 1 since ClosestListEntry starts at 0, not 1
      Type = CurrentEntry["name", string]
      Info = CurrentEntry["info", string]
    
      if (CurrentlySelected!=0) { # if something was previously selected
        EGP:egpColor(8+CurrentlySelected*2, vec(127)) # reset color of that entry
      }
      EGP:egpColor(8+ClosestListEntry*2, vec(64,127,64)) # change color of now selected entry
      CurrentlySelected = ClosestListEntry
    }
  }
}

```
This could easily be expanded into a simple shop or choosing the destination of a teleporter or elevator. To do this you could just replace the info-string with a price, or a location, or whatever.  

Some ideas you could try out based on this example:
* Make a 2d grid instead of a 1d list. Hint: Most math, including division and rounding works just as well on 2d-vectors
* Allow a longer list by adding scroll/page switch buttons, ie by making the for loop start and end based on variables
* Use more complicated entries. You could for example add buttons left and right of each entry to decrease/increase prices of that item (that only work for you ofc). Hint: You can reuse most of the calculation, no need to calculate `ClosestListEntry` multiple times, just add another inrange.