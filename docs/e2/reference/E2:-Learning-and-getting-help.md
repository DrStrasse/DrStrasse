Table of Contents
=================

   * [E2Helper](#e2helper)
      * [Interface](#interface)
      * [Searching by Parameters](#searching-by-parameters)
   * [Wiremod Wiki](#wiremod-wiki)
   * [Tutorials](#tutorials)
   * [Asking for Help](#asking-for-help)
      * [Bad Examples](#bad-examples)
      * [Good Examples](#good-examples)

# E2Helper

The E2Helper is a quite powerful tool to find functions. Unlike the Wiki it automatically contains every function, and is synced with the server, so you can also see any extensions the server has installed (and *only* those, if a extension is disabled, the functions will not show up).

You can open the E2Helper by clicking the button near the top right corner of the E2 Editor

## Interface

The top bar is for searching. In the left box you can search for functions by name, the other are for searching by parameter and return value respectively. All boxes can be used at the same time.

In the center you see function name, their "signature" (parameters and return value) as well as ops cost.  
Note: certain functions have a variable ops cost based on input size (usually those dealing with tables, arrays, strings), so do not overly rely on these numbers and rather use them as a rough value.

The bottom fields show how to use the currently selected function and usually contain a short descriptions

## Searching by Parameters

If you are learning E2 you might ask yourself "How do i get the size of a array" or similar questions.  
In this cases the parameter and return search boxes are exceptionally useful.

Just plug in what you think the function needs. Here we have an array (short type `r`) as input, and want a number (short type `n`) as result.  
Don't be discouraged if you get many results, just scroll through the list and see if something fits your needs. You might even encounter some useful functions to keep in for later.

In our example we quickly see `count`, which is used as `Size = Array:count()`.

Note: When searching for multiple inputs, try different orders and `:` placement.

# Wiremod Wiki
*Main article: [Guides & Tooling: Wiki Guides](/wiremod/wire/wiki/Expression-2-Guides-&-Tooling#guides)*

In addition to the dump of availiable functions (see the footer), this wiki contains quite a few Example, Tutorials and Info pages. Maybe someday there will be a nice Overview page...


# Tutorials
There are many tutorials out there, but most aren't very good.  
You will not learn much from copy-pasting code or typing what you see in YouTube video straight into the editor.

You probably know best how you like to learn, but here are a few general tips:

* Try to understand what exactly the code is doing, section by section, line by line
* Format your code correctly, especially use consistent [indentation](https://en.wikipedia.org/wiki/Indentation_(typesetting))
    This lets you keep track of sections of code easier, such as what part is repeated.  
    This not only helps you if you look back at old code, but also others, such as when asking for help.  
    The E2 Editor will automatically try to indent by itself, but sometimes gets a bit confused.
* Layout your code: You want to order and space code in a way that makes sense. You might want to throw in a empty line between certains sections here and there. I also recommend laying out your code as a elseif-chain as shown in [[E2: Triggers]]
* Don't be afraid to ask questions. If you cannot find someone on your server to help you, stop by #help on the discord.

# Asking for Help

If you want quick and useful help, try and explain your problem and context in a brief but easily understandable way.  
Also explain what your current ideas are and what you tried, people are far more happy to help if they see you already put some effort into solving it yourself, instead of spoonfeeding you every single thing.

## Bad Examples
* "How to make a shield with E2? Help me plz"
* "Why is my E2 not working? \<full e2 code, unformatted>"
* "How to find a string in an array?"

## Good Examples
* "I am trying to make a shield, and want it to stay between me and someone, and a certain distance from me, how can i calculate the position?"
* "I have trouble with \<line of code> inside my E2, it skips a turn every so often"
* "How to find a string in an array? I am trying to check if a player name is on a list"