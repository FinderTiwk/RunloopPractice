//
//  FKPersistentThreadPoolTests.m
//  FKPersistentThreadPoolTests
//
//  Created by _Finder丶Tiwk on 16/3/15.
//  Copyright © 2016年 _Finder丶Tiwk. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FKPersistentThreadPool.h"

@interface FKPersistentThreadPoolTests : XCTestCase

@end

@implementation FKPersistentThreadPoolTests

- (void)setUp {
    [super setUp];
    
    FKPersistentThreadPool *pool = [FKPersistentThreadPool shareInstance];
    [pool addTaskThreadWithID:@"001"];
    [pool addTaskThreadWithID:@"002" name:@"图片上传"];
    [pool addTaskThreadWithID:@"003" name:@"数据上传" stackSize:512];
    [pool addTaskThreadWithID:@"004" name:@"其它操作" stackSize:128 priority:NSQualityOfServiceDefault];
}

- (void)tearDown{
    [super tearDown];
//    FKPersistentThreadPool *pool = [FKPersistentThreadPool shareInstance];
//    [pool removeThreadWithID:@"001"];
//    [pool removeThreadWithID:@"002"];
//    [pool removeThreadWithID:@"003"];
//    [pool removeThreadWithID:@"004"];
    [[FKPersistentThreadPool shareInstance] removeAllThread];
}

- (void)testGet1{
    NSThread *thread = [[FKPersistentThreadPool shareInstance] threadWithID:@"001"];
    XCTAssertNotNil(thread);
    XCTAssertTrue([thread.name isEqualToString:@"XPersistentDefaultThread"]);
    XCTAssertTrue(thread.stackSize == 256*1024,@"创建的线程的栈空间与预期不符合");
    XCTAssertTrue(NSQualityOfServiceBackground==thread.qualityOfService);
}

- (void)testGet2{
    NSThread *thread = [[FKPersistentThreadPool shareInstance] threadWithID:@"002"];
    XCTAssertNotNil(thread);
    XCTAssertTrue([thread.name isEqualToString:@"图片上传"]);
    XCTAssertTrue(thread.stackSize == 256*1024,@"创建的线程的栈空间与预期不符合");
    XCTAssertTrue(NSQualityOfServiceBackground==thread.qualityOfService);
}


- (void)testGet3{
    NSThread *thread = [[FKPersistentThreadPool shareInstance] threadWithID:@"003"];
    XCTAssertNotNil(thread);
    XCTAssertTrue([thread.name isEqualToString:@"数据上传"]);
    XCTAssertTrue(thread.stackSize == 512*1024,@"创建的线程的栈空间与预期不符合");
    XCTAssertTrue(NSQualityOfServiceBackground==thread.qualityOfService);
}

- (void)testGet4{
    NSThread *thread = [[FKPersistentThreadPool shareInstance] threadWithID:@"004"];
    XCTAssertNotNil(thread);
    XCTAssertTrue([thread.name isEqualToString:@"其它操作"]);
    XCTAssertTrue(thread.stackSize == 128*1024,@"创建的线程的栈空间与预期不符合");
    XCTAssertTrue(NSQualityOfServiceDefault==thread.qualityOfService);
}


- (void)testThread001{
    BOOL transcation = [[FKPersistentThreadPool shareInstance] executeTask:^{
        NSLog(@"默认名称一 -- %@",[NSThread currentThread]);
    } withID:@"001"];
    XCTAssertTrue(transcation,@"001对应的线程不存在");
}

- (void)testThread002{
    BOOL transcation = [[FKPersistentThreadPool shareInstance] executeTask:^{
        NSLog(@"图片上传<%@>",[NSThread currentThread]);
    } withID:@"002" interval:2 delay:0 repeat:YES];
    XCTAssertTrue(transcation,@"002对应的线程不存在");
}

- (void)testThread003{
    __block NSUInteger count = 0;
    BOOL transcation = [[FKPersistentThreadPool shareInstance] executeTask:^{
        NSLog(@"第%zi次数据上传<%@>",++count,[NSThread currentThread]);
    } withID:@"003" interval:3 delay:0 repeat:YES];
    XCTAssertTrue(transcation,@"003对应的线程不存在");
}

- (void)testThread004{
    BOOL transcation = [[FKPersistentThreadPool shareInstance] executeTask:^{
        NSLog(@"其它操作 -- %@",[NSThread currentThread]);
    } withID:@"004"];
    XCTAssertTrue(transcation,@"004对应的线程不存在");
}

- (void)testThread005{
    BOOL transcation = [[FKPersistentThreadPool shareInstance] executeTask:^{
        NSLog(@"其它操作 -- %@",[NSThread currentThread]);
    } withID:@"005"];
    XCTAssertFalse(transcation,@"005对应的线程不存在");
}

@end
