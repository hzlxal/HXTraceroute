//
//  HXTraceroute.h
//  MyTraceroute
//
//  Created by hzl on 2018/5/27.
//  Copyright © 2018年 hzl. All rights reserved.
//

#import <Foundation/Foundation.h>
@class HXTracerouteRecord;

@interface HXTraceroute : NSObject
/**
 Traceroute每一步的回调

 @param record 记录结果的对象
 */
typedef void(^TracerouteStepCompletedBlock)(HXTracerouteRecord *record);

/**
 Traceroute结束时的回调

 @param result 记录所有结果的数组
 @param succedd 是否成功到达目的主机
 */
typedef void(^TraceroutAllCompletedBlock)(NSArray<HXTracerouteRecord *> *result, BOOL succedd);


/**
 进行Traceroute

 @param host 目的域名或IP地址
 @param stepCompletedBlk 每一跳的结果回调
 @param allCompletedBlk Traceroute结束的回调
 */
+ (void)startTracerouteWithHost:(NSString *)host
               stepCompletedBlk:(TracerouteStepCompletedBlock)stepCompletedBlk andAllCompletedBlk:(TraceroutAllCompletedBlock)allCompletedBlk;
@end
