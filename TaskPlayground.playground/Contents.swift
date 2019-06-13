//: TaskPlayground: a simple helper for grouping together pieces of code that are run asynchronously

//:
// The main requirement was to execute an async task on a background queue, followed by a UI
// update on the main queue, and be able to wait on the completion of both for the execution
// of yet another block of code

import Cocoa
import PlaygroundSupport

public func defaultQueueProvider() -> TaskQueueProviderType {
    struct Provider : TaskQueueProviderType {
        func getQueue() -> DispatchQueue {
            return utilityQueue()
        }
    }
    return Provider()
}

public func backgroundQueueProvider() -> TaskQueueProviderType {
    struct Provider : TaskQueueProviderType {
        func getQueue() -> DispatchQueue {
            return backgroundQueue()
        }
    }
    return Provider()
}

public func mainQueueProvider() -> TaskQueueProviderType {
    struct Provider : TaskQueueProviderType {
        func getQueue() -> DispatchQueue {
            return mainQueue()
        }
    }
    return Provider()
}

func mainQueue() -> DispatchQueue {
    return DispatchQueue.main
}

func userInitiatedQueue() -> DispatchQueue {
    return DispatchQueue.global(qos: .userInitiated)
}

func utilityQueue() -> DispatchQueue {
    return DispatchQueue.global(qos: .utility)
}

func backgroundQueue() -> DispatchQueue {
    return DispatchQueue.global(qos: .background)
}

public protocol TaskQueueProviderType {
    func getQueue() -> DispatchQueue
}

public typealias TaskBlock = () -> Void
public struct TaskGroup {
    
    let _group: DispatchGroup
    let _queueProvider: TaskQueueProviderType
    
    public init() {
        self.init(defaultQueueProvider())
    }
    public init(_ queueProvider:TaskQueueProviderType) {
        _group = DispatchGroup()
        _queueProvider = queueProvider
    }
    
    public func join(seconds timeout: Double! = nil, completion:@escaping TaskBlock) {
        if timeout != nil {
            join(millis: timeout*1000, completion: completion)
        } else {
            _group.wait(timeout: .distantFuture)
        }
    }
    
    public func join(millis timeout: Double! = nil, completion:TaskBlock?) {
        if let handler = completion {
            _group.notify(queue: _queueProvider.getQueue()) {
                handler()
            }
        }
        if timeout != nil {
            let nanos = Int(Double(timeout) * Double(NSEC_PER_MSEC))
            let time: DispatchTime = .now() + .nanoseconds(nanos)
            _group.wait(timeout: time)
        } else {
            _group.wait(timeout: .distantFuture)
        }
    }
    
    public func asyncMainAfter(millis timeout: Double, block: @escaping TaskBlock) {
        let nanos = Int(Double(timeout) * Double(NSEC_PER_MSEC))
        let time: DispatchTime = .now() + .nanoseconds(nanos)
        mainQueue().asyncAfter(deadline: time, execute: _exec(block))
    }
    
    public func asyncMain(block: @escaping TaskBlock) {
        mainQueue().async(execute: _exec(block))
    }
    
    public func asyncAfter(millis timeout: Double, block: @escaping TaskBlock) {
        let nanos = Int(Double(timeout) * Double(NSEC_PER_MSEC))
        let time: DispatchTime = .now() + .nanoseconds(nanos)
        _queueProvider.getQueue().asyncAfter(deadline: time, execute: _exec(block))
    }
    public func async(block: @escaping TaskBlock) {
        _queueProvider.getQueue().async(execute: _exec(block))
    }
    
    func _exec(_ block: @escaping TaskBlock) -> ()->Void {
        let group = self._group
        group.enter()
        return {
            block()
            group.leave()
        }
    }
    
}

// --------------------------------------


print("00-Starting background tasks")

backgroundQueueProvider().getQueue().async {

//    let timer = StopWatch()
    print("10-Running async")

    let tg = TaskGroup(backgroundQueueProvider())
    print("20-group created")

    tg.asyncAfter(millis: 3000) {
        print("70-wait 3.0s - T1 background queue")
    }
    print("30-T1 started")

    tg.asyncMainAfter(millis:1500) {
        print("60-wait 1.5s (doFirst) - T2 MAIN queue")
    }
    print("40-T2 started")

    print("50-WAIT for completion")
    tg.join(millis:20000) {
        print("110-ALL COMPLETED")
    }
    print("120-WAITED")
//    print ("Duration: \(timer.elapsed) \(timer.total)")

    PlaygroundPage.current.finishExecution()

}

PlaygroundPage.current.needsIndefiniteExecution = true

/*:
 Hello World!!!
 00-Starting background tasks
 Duration: 0.007333993911743164
 10-Running async
 20-created
 30-Task1 created
 40-Task2 created
 100-WAIT for completion
 50-wait 1.5s (doFirst) - MAIN queue
 60-wait 3s - background queue
 110-ALL COMPLETED
 120-WAITED
*/
