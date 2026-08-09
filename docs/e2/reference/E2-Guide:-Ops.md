## What are ops?
*Ops* are E2's main method of limiting its performance cost. Every single action in E2 is assigned an op cost, ranging from fractions to hundreds. Ops provide a simple way to track performance in a way that is the same for every user: as long as you stay under the quota, your E2 chip will run on every server you visit. When you reach the *op quota*, the maximum limit of ops you can have at any moment, your chip will halt and error. *Generally speaking*, a chip with a lower op cost is more efficient than a chip with a higher op cost.

> [!NOTE]
> Op costs are subject to change. Some op costs do not reflect the performance of functions accurately.


### Op quotas

Ops are a "leaky bucket" system. To explain, let's use an analogy. Imagine you have a bucket with a hole in it. Say your bucket can store 1000 drops of water, and it has a hole in it that drops 100 drops per second. You have a spoon that stores up to 250 drops. Whenever you add water, you can add at most 250 drops with that spoon, but every second the bucket still loses 100 drops. Eventually, if you keep filling the bucket consistently, you will overflow the bucket. The ops system works in a similar way, just instead of overflowing, your chip crashes, and instead of seconds, the timescale is in ticks.

There are three op quotas used by E2; soft quota, hard quota, and tick quota. Soft quota is the amount of ops you can use in a tick before you run into "op debt", which is where you start adding to the op count. Hard quota is the maximum amount of "op debt" that you can have at any moment<sup>1</sup>. Tick quota is the maximum number of ops you can use over a single tick. For the most part, the differences of these quotas aren't very significant to know as you'll mostly only be working around the soft quota and tick quota. By default, quotas are `10,000`, `100,000`, and `25,000` for soft, hard, and tick quota respectively.

<sub>1: More specifically, hard quota is determined by `op count + current ops - soft quota`, and `op count = max((op count + current ops - soft quota), 0)` which gets recalculated every tick. *current ops* is the amount of ops used in the current tick.</sub>

### Why ops?
Ops have been decided as the simplest and most efficient solution to ensure players don't crash servers with expensive E2 chips. The main benefits of ops are that they are consistent, so two servers with similar quotas can run the same chips, and that they are lightweight, being only a number that's incremented as opposed to CPU time benchmarking which varies greatly depending on outside factors. Additionally, ops provide a built-in method to openly discourage using certain functions, by increasing the cost associated with them.

## Avoiding op quotas
The easiest way to avoid reaching op quotas is to write efficient code. Usually this is in more obvious forms such as using `for` instead of `while` and avoiding redundant expressions, but sometimes it may take some ingenuity and scouring of the E2Helper or Wiki to find more efficient methods of accomplishing a task. Alternatively, you can use the functions `perf()` or `perf(n)` in your code to query if your chip has reached a percentage of the op quota.

```ruby
I = 0
while(perf(80)) { # Runs the loop until the chip reaches 80% quota usage
   I++
}
print(I)
```

By combining `perf()` with timers, you can use it to split a loop among multiple executions.

```ruby
let Index = 1 # An upvalue to track position between runs.
timer("iter", 0, 0, function() { # Run a timer to process the above code in a perf-safe way
    for(I = Index, Max) {
        if(perf()) {
            # ... code
        } else { 
            Index = I
            break
        }
    }
    if(Index >= Max) { # Check if the loop ended because it reached the end
        stoptimer("iter")
        # Trigger some signal/timer to indicate the loop is finished
    }
})
```