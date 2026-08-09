# Expression 2: Core Functions  
| Function       | Returns                             | Description                                                 |
| -------------- |:-----------------------------------:| ----------------------------------------------------------- |
| first()        | ![Number](Type-Number.png "Number") | Returns `1` if the expression was spawned or reset            |
| duped()        | ![Number](Type-Number.png "Number") | Returns `1` if the expression was duplicated                  |
| dupefinished() | ![Number](Type-Number.png "Number") | Returns `1` when the contraption has finished duping. (Only triggers on Adv Duplicator, not the normal duplicator) |
| inputClk()     | ![Number](Type-Number.png "Number") | Returns `1` if the expression was triggered by an input       |
| reset()        |  | Reset the expression itself as if it was just spawned, stops execution |
| exit()        |  | Stops the execution of any code after it                    |
| runOnLast(![Number](Type-Number.png "Number"))  | ![Number](Type-Number.png "Number") | Returns `1` if it is being called on the last execution of the expression gate before it is removed or reset. This execution must be requested with the `runOnLast(1)` command. |
| last()        | ![Number](Type-Number.png "Number") | Returns `1` if this is the last execution.                  |
| removing()        | ![Number](Type-Number.png "Number") | Returns `1` if this is the `last()` execution and caused by the entity being removed. |
| ops()        | ![Number](Type-Number.png "Number") | Returns how many ops are used every execution on average |
| cpuUsage()        | ![Number](Type-Number.png "Number") | 	Returns the average cpu usage in seconds. Multiply it by `1000000` to get the same number you see in `E2`'s overlay text. |
| opcounter()        | ![Number](Type-Number.png "Number") | Returns how many `ops` have been used so far in this execution plus the amount of hard quota used |
| minquota()        | ![Number](Type-Number.png "Number") | The ops left before soft quota is used up |
| maxquota()        | ![Number](Type-Number.png "Number") | The ops left before hard quota is exceeded and the expression shuts down |
| softQuota()        | ![Number](Type-Number.png "Number") | Returns the size of the soft quota |
| hardQuota()        | ![Number](Type-Number.png "Number") | Returns the size of the hard quota |
| perf()        | ![Number](Type-Number.png "Number") | If used as a while loop condition, stabilizes the expression around `<maxexceed></maxexceed>` hardquota used. |
| perf(![Number](Type-Number.png "Number"))        | ![Number](Type-Number.png "Number") | Same as `perf()`, where ![Number](Type-Number.png "Number") is the percentage of the soft quota the `E2` will stabilise at. |