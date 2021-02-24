# FKPersistentThreadPool
NSRunLoop常驻线程工具类

## Tips

1. 任务执行完成,线程就消亡了 #issue: attempt to start the thread again

2. This value must be in bytes and a multiple of 4KB.minimum 16KB default 512KB subThread  ,1M mainThread

3. 线程创建大约消耗90毫秒

4. NSRunLoop[Set<CFRunLoopSourceRef>,Array<CFRunLoopTimerRef>,Array<CFRunLoopObserverRef>],如果RunLoop当前模式里没有 Source Timer runLoop就退出了

5. CFRunLoopSourceRef 事件源

>  Source1 -->Source0
>  Source0(触摸事件处理, performSelector:onThread:方法)
>  Source1(系统事件,基本端口的线程间通讯)

6. 常见的几种RunLoop模式：NSDefaultRunLoopMode,UITrackingRunLoopMode,NSRunLoopCommonModes

7. autoreleasepool 在runLoop开启时(kCFRunLoopEntry)创建,休眠前(kCFRunLoopBeforeWaiting)销毁并创建,退出时(kCFRunLoopExit)再销毁

8. CFRunLoopObserverRef 负责监听RunLoop状态

```ObjectiveC
- (void)note_CFRunLoopObserverRef{
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(), kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
    switch (activity) {
        case kCFRunLoopEntry: {// 即将进入Loop(1UL << 0)
            NSLog(@"runLoop进入< %@ >状态",@"kCFRunLoopEntry");
            break;
        }
        case kCFRunLoopBeforeTimers: {// 即将处理 Timer(1UL << 1)
            NSLog(@"runLoop进入< %@ >状态",@"kCFRunLoopBeforeTimers");
            break;
        }
        case kCFRunLoopBeforeSources: {// 即将处理 Source(1UL << 2)
            NSLog(@"runLoop进入< %@ >状态",@"kCFRunLoopBeforeSources");
            break;
        }
        case kCFRunLoopBeforeWaiting: {// 即将进入休眠(1UL << 5)
            NSLog(@"runLoop进入< %@ >状态",@"kCFRunLoopBeforeWaiting");
            break;
        }
        case kCFRunLoopAfterWaiting: {// 刚从休眠中唤醒(1UL << 6)
            NSLog(@"runLoop进入< %@ >状态",@"kCFRunLoopAfterWaiting");
            break;
        }
        case kCFRunLoopExit: {// 即将退出Loop(1UL << 7)
            //RunLoop发生意外或超时时会进入,所以基本不会退出
            NSLog(@"runLoop进入< %@ >状态",@"kCFRunLoopExit");
            break;
        }
        case kCFRunLoopAllActivities: {// 监听所有状态(0x0FFFFFFFU)
            NSLog(@"runLoop进入< %@ >状态",@"kCFRunLoopAllActivities");
            break;
        }
    }
    });
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    CFRelease(observer);
}

```

    
