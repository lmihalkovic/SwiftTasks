//: TaskPlayground: a simple helper for grouping together pieces of code that are run asynchronously

//: The main requirement was to execute an async task on a background queue, followed by a UI update on the main queue, and be able to wait on the completion of both for the execution of yet another block of code

import Cocoa
import XCPlayground

public func defaultQueueProvider() -> TaskQueueProviderType {
    struct Provider : TaskQueueProviderType {
        func getQueue() -> dispatch_queue_t {
            return utilityQueue()
        }
    }
    return Provider()
}

public func backgroundQueueProvider() -> TaskQueueProviderType {
    struct Provider : TaskQueueProviderType {
        func getQueue() -> dispatch_queue_t {
            return backgroundQueue()
        }
    }
    return Provider()
}

public func mainQueueProvider() -> TaskQueueProviderType {
    struct Provider : TaskQueueProviderType {
        func getQueue() -> dispatch_queue_t {
            return mainQueue()
        }
    }
    return Provider()
}

func mainQueue() -> dispatch_queue_t {
    return dispatch_get_main_queue()
}

func userInitiatedQueue() -> dispatch_queue_t {
    return dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
}

func utilityQueue() -> dispatch_queue_t {
    return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
}

func backgroundQueue() -> dispatch_queue_t {
    return dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
}

public protocol TaskQueueProviderType {
    func getQueue() -> dispatch_queue_t
}

public typealias TaskBlock = () -> Void
public struct TaskGroup {
    
    let _group: dispatch_group_t
    let _queueProvider: TaskQueueProviderType
    
    public init() {
        self.init(defaultQueueProvider())
    }
    public init(_ queueProvider:TaskQueueProviderType) {
        _group = dispatch_group_create()
        _queueProvider = queueProvider
    }
    
    public func join(seconds timeout: Double! = nil, completion:TaskBlock) {
        if timeout != nil {
            join(millis: timeout*1000, completion: completion)
        } else {
            dispatch_group_wait(_group, DISPATCH_TIME_FOREVER)
        }
    }
    
    public func join(millis timeout: Double! = nil, completion:TaskBlock?) {
        if let handler = completion {
            dispatch_group_notify(_group, _queueProvider.getQueue()) {
                handler()
            }
        }
        if timeout != nil {
            let nanos = Int64(Double(timeout) * Double(NSEC_PER_MSEC))
            let time = dispatch_time(DISPATCH_TIME_NOW, nanos)
            dispatch_group_wait(_group, time)
        } else {
            dispatch_group_wait(_group, DISPATCH_TIME_FOREVER)
        }
    }
    
    public func asyncMain(millis timeout: Double, block: TaskBlock) {
        let nanos = Int64(Double(timeout) * Double(NSEC_PER_MSEC))
        let time = dispatch_time(DISPATCH_TIME_NOW, nanos)
        dispatch_after(time, dispatch_get_main_queue(), _exec(block))
    }
    
    public func asyncMain(block: TaskBlock) {
        dispatch_async(dispatch_get_main_queue(), _exec(block))
    }
    
    public func async(millis timeout: Double, block: TaskBlock) {
        let nanos = Int64(Double(timeout) * Double(NSEC_PER_MSEC))
        let time = dispatch_time(DISPATCH_TIME_NOW, nanos)
        dispatch_after(time, _queueProvider.getQueue(), _exec(block))
    }
    public func async(block: TaskBlock) {
        dispatch_async(_queueProvider.getQueue(), _exec(block))
    }
    
    func _exec(block: TaskBlock) -> dispatch_block_t {
        let group = self._group
        dispatch_group_enter(group)
        return {
            block()
            dispatch_group_leave(group)
        }
    }
    
}

// --------------------------------------

dispatch_async(backgroundQueue()) {
    print("Running async")
    
    let tg = TaskGroup(backgroundQueueProvider())
    print("created")
    
    tg.async(millis: 3000) {
        print("wait 3s - background queue")
    }
    print("Task1 created")
    
    tg.asyncMain(millis:1500) {
        print("wait 1.5s (doFirst) - MAIN queue")
    }
    print("Task2 created")
    
    print("WAIT for completion")
    tg.join(millis:20000) {
        print("ALL COMPLETED")
    }
    print("WAITED")
}


XCPlaygroundPage.currentPage.needsIndefiniteExecution = true
