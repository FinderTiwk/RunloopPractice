//
//  FKPersistentThreadPool.m
//  FKPersistentThreadPool
//
//  Created by _Finder丶Tiwk on 16/3/15.
//  Copyright © 2016年 _Finder丶Tiwk. All rights reserved.
//

#import "FKPersistentThreadPool.h"
#import <pthread/pthread.h>

#pragma mark - ###线程池元素
@interface FKThreadPoolItem : NSObject
@property (nonatomic,strong) NSTimer  *timer;
@property (nonatomic,strong) NSThread *thread;
@end

@implementation FKThreadPoolItem
@end

////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
#pragma mark - ### 常驻线程池
@interface FKPersistentThreadPool ()
@property (nonatomic,strong) NSMutableDictionary<NSString *,FKThreadPoolItem *> *threadMap;
@property (nonatomic,assign) pthread_mutex_t pLock;
@end

@implementation FKPersistentThreadPool

static FKPersistentThreadPool *__instance;
+ (instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __instance = [super allocWithZone:zone];
        __instance.threadMap = [NSMutableDictionary dictionaryWithCapacity:5];
        
        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
        pthread_mutex_init(&__instance->_pLock, &attr);
        pthread_mutexattr_destroy(&attr);
    });
    return __instance;
}
+ (instancetype)shareInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __instance = [[self alloc] init];
    });
    return __instance;
}

#pragma mark - 添加一个常驻线程
- (void)addTaskThreadWithID:(NSString *)ID{
    [self addTaskThreadWithID:ID
                         name:@"XPersistentDefaultThread"];
}

- (void)addTaskThreadWithID:(NSString *)ID name:(NSString *)name{
    [self addTaskThreadWithID:ID
                         name:name
                    stackSize:256];
}

- (void)addTaskThreadWithID:(NSString *)ID
                       name:(NSString *)name
                  stackSize:(NSUInteger)stackSize{
    [self addTaskThreadWithID:ID
                         name:name
                    stackSize:stackSize
                     priority:NSQualityOfServiceBackground];
}

- (void)addTaskThreadWithID:(NSString *)ID
                       name:(NSString *)name
                  stackSize:(NSUInteger)stackSize
                   priority:(NSQualityOfService)priority{
    
    NSParameterAssert(ID);
    NSParameterAssert(name);
    NSAssert(stackSize >= 16 , @"stackSize 最小应该为16KB");
    NSAssert(stackSize <= 512, @"stackSize 最大应该为512KB");
    NSAssert(stackSize%4 == 0, @"stackSize 应该为4的倍数");
    
    NSThread *taskThread = [[NSThread alloc] initWithTarget:self
                                                   selector:@selector(taskRun)
                                                     object:nil];
    taskThread.name             = name;
    taskThread.stackSize        = stackSize*1024;
    taskThread.qualityOfService = priority;
    [taskThread start];
    
    FKThreadPoolItem *item = [FKThreadPoolItem new];
    item.thread = taskThread;
    pthread_mutex_lock(&_pLock);
    [_threadMap setObject:item forKey:ID];
    pthread_mutex_unlock(&_pLock);
}

#pragma mark - 其它方法
- (NSThread *)threadWithID:(NSString *)ID{
    NSParameterAssert(ID);
    pthread_mutex_lock(&_pLock);
    NSThread *thread = [_threadMap valueForKey:ID].thread;
    pthread_mutex_unlock(&_pLock);
    return thread;
}

- (void)removeThreadWithID:(NSString *)ID{
    NSParameterAssert(ID);
    FKThreadPoolItem *poolItem = [_threadMap valueForKey:ID];
    if (poolItem) {
        // 1.退出线程
        NSThread *specifyThread = poolItem.thread;
        if (specifyThread) {
            [specifyThread cancel];
        }
        // 2.停止定时器
        NSTimer *timer = poolItem.timer;
        if (timer) {
            [timer invalidate];
            timer = nil;
        }
        // 3.将item从池中移除
        pthread_mutex_lock(&self->_pLock);
        [_threadMap removeObjectForKey:ID];
        pthread_mutex_unlock(&self->_pLock);
    }
}

- (void)removeAllThread{
    [_threadMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, FKThreadPoolItem * _Nonnull obj, BOOL * _Nonnull stop) {
        // 1.退出线程
        NSThread *specifyThread = obj.thread;
        if (specifyThread) {
            [specifyThread cancel];
        }
        // 2.停止定时器
        NSTimer *timer = obj.timer;
        if (timer) {
            [timer invalidate];
            timer = nil;
        }
        pthread_mutex_lock(&self->_pLock);
        [self->_threadMap removeObjectForKey:key];
        pthread_mutex_unlock(&self->_pLock);
    }];
}

#pragma mark - 具体实现
#pragma mark  普通任务的实现
- (BOOL)executeTask:(void (^)(void))task withID:(NSString *)ID{
    NSParameterAssert(task);
    NSThread *specifyThread = [self threadWithID:ID];
    if (specifyThread) {
        [self performSelector:@selector(executeTask:)
                     onThread:specifyThread
                   withObject:task
                waitUntilDone:NO];
        return YES;
    }else{
        NSLog(@"此ID(%@)对应的线程不存在",ID);
        return NO;
    }
}

- (void)executeTask:(void (^)(void))task{
    task();
}

#pragma mark 定时任务的实现
- (BOOL)executeTask:(void (^)(void))task
             withID:(NSString *)ID
           interval:(NSTimeInterval)interval{
    return [self executeTask:task
                      withID:ID
                    interval:interval
                       delay:0];
}
- (BOOL)executeTask:(void (^)(void))task
             withID:(NSString *)ID
           interval:(NSTimeInterval)interval
              delay:(NSTimeInterval)delay{
    return [self executeTask:task
                      withID:ID
                    interval:interval
                       delay:delay
                      repeat:NO];
}

- (BOOL)executeTask:(void (^)(void))task withID:(NSString *)ID interval:(NSTimeInterval)interval delay:(NSTimeInterval)delay repeat:(BOOL)repeat{
    NSParameterAssert(task);
    NSParameterAssert(ID);
    pthread_mutex_lock(&_pLock);
    FKThreadPoolItem *item = [_threadMap valueForKey:ID];
    pthread_mutex_unlock(&_pLock);
    NSThread *specifyThread = item.thread;
    if (specifyThread) {
        NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:delay] interval:interval target:self selector:@selector(runTimer:) userInfo:@{@"task":task} repeats:repeat];
        item.timer = timer;
        
        [self performSelector:@selector(executeTimer:)
                     onThread:specifyThread
                   withObject:timer
                waitUntilDone:NO];
        return YES;
    }else{
        NSLog(@"此ID(%@)对应的线程不存在",ID);
        return NO;
    }
}

- (void)executeTimer:(NSTimer *)timer{
    [[NSRunLoop currentRunLoop] addTimer:timer
                                 forMode:NSDefaultRunLoopMode];
}

- (void)runTimer:(NSTimer *)timer{
    void (^task)(void) = timer.userInfo[@"task"];
    task();
}

- (void)taskRun{
    @autoreleasepool {
        NSLog(@"启动%@线程中的Runloop",[NSThread currentThread].name);
        [[NSRunLoop currentRunLoop] addPort:[NSPort port]
                                    forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run];
    }
}

@end
