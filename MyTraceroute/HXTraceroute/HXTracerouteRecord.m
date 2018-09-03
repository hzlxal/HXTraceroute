//
//  HXTracerouteRecord.m
//  MyTraceroute
//
//  Created by hzl on 2018/5/27.
//  Copyright © 2018年 hzl. All rights reserved.
//

#import "HXTracerouteRecord.h"

@implementation HXTracerouteRecord

//重写description方法使其能返回每一条的描述
- (NSString *)description{
    NSMutableString *record = [[NSMutableString alloc] initWithCapacity:20];
    [record appendFormat:@"%ld\t", (long)self.ttl];
    
    if (self.currentIP == nil) {
        [record appendFormat:@" \t"];
    } else {
        [record appendFormat:@"%@\t", self.currentIP];
    }
    
    //
    for (id number in self.durations) {
        if ([number isKindOfClass:[NSNull class]]) {
            [record appendFormat:@"*\t"];
        } else {
            [record appendFormat:@"%.2f ms\t", [(NSNumber *)number floatValue] * 1000];
        }
    }
    
    return record;
}

@end
