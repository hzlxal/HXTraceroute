//
//  HXTracerouteRecord.h
//  MyTraceroute
//
//  Created by hzl on 2018/5/27.
//  Copyright © 2018年 hzl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HXTracerouteRecord : NSObject

//当前这一跳的IP
@property (nonatomic, copy) NSString *currentIP;
//每个的往返耗时的数组
@property (nonatomic, copy) NSArray<NSNumber *> *durations;
//次数
@property (nonatomic, assign) NSInteger count;
//当前的TTL
@property (nonatomic, assign) NSInteger ttl;


@end
