TaskPlayground
==============

A simple helper for grouping together pieces of code that are run asynchronously

The main requirement was to execute an async task on a background queue, followed by a UI update on the main queue, and be able to wait on the completion of both for the execution of yet another block of code

Example:

```swift
    
    let tg = TaskGroup(backgroundQueueProvider())
    
    tg.async(millis: 3000) {
        print("wait 3s - background queue")
    }
    
    tg.asyncMain(millis:1500) {
        print("wait 1.5s (doFirst) - MAIN queue")
    }
    
    // Wait 20s max and execute completion
    print("WAIT for completion")
    tg.join(millis:20000) {
        print("ALL COMPLETED")
    }
    print("WAITED")
    
```

will result in the following output



```
WAIT for completion
wait 1.5s (doFirst) - MAIN queue
wait 3s - background queue
ALL COMPLETED
WAITED
```

