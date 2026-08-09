This wiki has been created so that everyone with a github account can contribute to the documentation, so please do.  If what you are looking for isn't listed here, use [the subreddit](https://www.reddit.com/r/wiremod) or the [Discord server](https://discord.gg/H8UKY3Y).

## Learn E2
* [Syntax](Expression-2-Syntax) - Start here to learn E2's syntax
* [Directives](Expression-2-Directives) - Learn what directives like ``@strict``, ``@autoupdate``, ``@trigger`` and ``@persist`` do
* [Editor](Expression-2-Editor) - See editor shortcuts <!--& how to configure the editor-->
* [Guides & Tooling](Expression-2-Guides-&-Tooling) - Guides and tools to help with writing E2

## Console Commands

| Command                                        | Description                                                                                                                                                        |
|------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| wire_expression2_model <model>                 | Manually changes the expression's model                                                                                                                            |
| wire_expression2_reload                        | Reloads all E2 extensions, useful for debugging your own extensions. Keep in mind that client-side files will be taken from gmod's cache in multi-player mode.     |
| wire_expression2_debug 0/1                     | Toggles debug mode, which shows info that might be useful for the developers. You need to do "wire_expression2_reload" after changing for this to have any effect. |
| wire_expression2_extension_enable <extension>  | Enables the specified extension.                                                                                                                                   |
| wire_expression2_extension_disable <extension> | Disables the specified extension.                                                                                                                                  |
| wire_expression2_unlimited 0/1                 | Enables/disables performance limiting.                                                                                                                             |

Note: Most E2 addons do not register themselves as extensions and thus cannot be turned on or off with the above commands. A notable exception is the [[Prop-core]] extension, which is disabled by default.

Also, you must run wire_expression2_reload in order for enabling/disabling extensions to take effect.

<!--
## Credits
I would like to extend thanks to all of the following people who have made contributions to Expression 2 in one way or another, making it into what it is today.

'''Shandolum, ZeikJT, Jimlad, Beer, Magos Mechanicus, Gwahir, chinoto, pl0x, Turck3, Ph3wl, Hunter234564, Fishface60, GUN, Bobsymalone, TomyLobo, Tolyzor, Jeremydeath, I am McLovin, Fizyk, Divran, Nebual, Rusketh'''

And of course all you others out there who use it, provide constructive feedback or help others become familiar with it!

Thank you! // Syranide

''P.S. I'm sorry if I forgot to mention someone!''
-->