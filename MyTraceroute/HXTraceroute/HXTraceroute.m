//
//  HXTraceroute.m
//  MyTraceroute
//
//  Created by hzl on 2018/5/27.
//  Copyright © 2018年 hzl. All rights reserved.
//

#import "HXTraceroute.h"
#import "HXTracerouteRecord.h"
#import "HXTracerouteTool.h"

#define kMaxAttempts 3 //每一条尝试的次数
#define kPort 20000 //traceroute使用的端口号
#define kMaxJump 30 //最多尝试30跳

@interface HXTraceroute()

//目的主机IP
@property (nonatomic, copy) NSString *ipAddress;
//目的主机域名
@property (nonatomic, copy) NSString *hostName;
//最大跳数
@property (nonatomic, assign) NSUInteger maxTTL;
//最终结果
@property (nonatomic, strong) NSMutableArray<HXTracerouteRecord *> *results;
//每跳回调的block
@property (nonatomic, copy) TracerouteStepCompletedBlock stepBlock;
//结束时的block
@property (nonatomic, copy) TraceroutAllCompletedBlock allBlock;

@end

@implementation HXTraceroute

+ (void)startTracerouteWithHost:(NSString *)host
               stepCompletedBlk:(TracerouteStepCompletedBlock)stepCompletedBlk andAllCompletedBlk:(TraceroutAllCompletedBlock)allCompletedBlk{
    
    HXTraceroute *traceroute = [[HXTraceroute alloc] initWithHost:host maxTTL:kMaxJump stepCompletedBlk:stepCompletedBlk andAllCompletedBlk:allCompletedBlk];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
           [traceroute run];
    });
}

#pragma mark -- private method
- (instancetype)initWithHost:(NSString *)hostName maxTTL:(NSUInteger)maxTTL stepCompletedBlk:(TracerouteStepCompletedBlock)stepCompletedBlk andAllCompletedBlk:(TraceroutAllCompletedBlock)allCompletedBlk{
    
    self = [super init];
    
    if (self) {
        self.hostName = hostName;
        self.maxTTL = maxTTL;
        self.stepBlock = stepCompletedBlk;
        self.allBlock = allCompletedBlk;
    }
    
    return self;
}

- (void)run{
    //进行域名解析获取ip地址表
    NSArray *ipList = [HXTracerouteTool getIPListWithHost:self.hostName];
    if (ipList.count == 0) {
        NSLog(@"解析失败");
        return;
    }
    //多个域名时取第一个域名
    self.ipAddress = [ipList firstObject];
    if (ipList.count > 0) {
        NSLog(@"%@ has multiple address, using %@",self.hostName, self.ipAddress);
    }
    
    //目的主机地址
    struct sockaddr *remoteAddr = [HXTracerouteTool getSockaddrWithAddress:self.ipAddress port:kPort];
    
    //创建套接字
    int send_sock;
    //通过SOCK_DGRAM和IPPROTO_ICMP直接创建ICMP套接字
    if ((send_sock = socket(remoteAddr->sa_family, SOCK_DGRAM, IPPROTO_ICMP)) < 0) {
        NSLog(@"创建失败!");
        return;
    }
    
    //超时时间设定为3秒
    struct timeval timeout;
    timeout.tv_sec = 1;
    timeout.tv_usec = 0;
    //定义套接字选项
    setsockopt(send_sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout));
    
    //初始化跳数
    int ttl = 1;
    BOOL succeed = NO;
    
    //进行traceroute
    do {
        // 设置数据包TTL，依次递增
        if (setsockopt(send_sock, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl)) < 0) {
            NSLog(@"TTL设置失败");
        }
        //发送ICMP回显请求
        succeed = [self sendAndRecv:send_sock addr:remoteAddr ttl:ttl];
        
    } while (++ttl <= self.maxTTL && !succeed);
    
    //释放addr的内存
    free(remoteAddr);
    //关闭套接字
    close(send_sock);
    
    // traceroute结束，回调结果
    if (self.allBlock) {
        self.allBlock([_results copy], succeed);
    }
}


/**
 向指定目标连续发送3个数据包
 
 @param sendSock 发送用的socket
 @param addr     地址
 @param ttl      TTL大小
 @return 如果找到目标服务器则返回YES，否则返回NO
 */
- (BOOL)sendAndRecv:(int)sendSock addr:(struct sockaddr *)addr ttl:(int)ttl {
    //数据缓冲区
    char buffer[200];
    BOOL finished = NO;
    
    socklen_t addrLen = sizeof(struct sockaddr_in);
    
    // 构建ICMP报文
    uint16_t identifier = (uint16_t)ttl;
    //创建ICMP报文头部
    NSData *packetData = [HXTracerouteTool getICMPPacketWithID:identifier sequenceNumber:ttl];
    
    // 记录结果
    HXTracerouteRecord *record = [[HXTracerouteRecord alloc] init];
    record.ttl = ttl;
    
    BOOL receiveReply = NO;
    NSMutableArray *durations = [[NSMutableArray alloc] init];
    
    // 连续发送3个ICMP报文，记录开始时间
    for (int try = 0; try < kMaxAttempts; try ++) {
    NSDate *startTime = [NSDate date];
    // 发送ICMP报文
    ssize_t sent = sendto(sendSock, packetData.bytes, packetData.length, 0, addr, addrLen);
        
    if (sent < 0) {
        NSLog(@"发送失败: %s", strerror(errno));
        [durations addObject:[NSNull null]];
        continue;
    }
        
    // 接收ICMP数据
    struct sockaddr remoteAddr;
    ssize_t resultLen = recvfrom(sendSock, buffer, sizeof(buffer), 0, (struct sockaddr*)&remoteAddr, &addrLen);
    
    if (resultLen < 0) {
        //失败
        [durations addObject:[NSNull null]];
        continue;
    } else {
        
        receiveReply = YES;
        //计算往返时间
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startTime];
            
        // 解析IP地址
        NSString* remoteAddress = nil;
        char ip[INET_ADDRSTRLEN] = {0};
        
        inet_ntop(AF_INET, &((struct sockaddr_in *)&remoteAddr)->sin_addr.s_addr, ip, sizeof(ip));
        remoteAddress = [NSString stringWithUTF8String:ip];
            
        // 结果判断
        if ([HXTracerouteTool isTimeOutPacket:(char *)buffer packetLength:(int)resultLen]) {
            // 到达中间节点
            [durations addObject:@(duration)];
            record.currentIP = remoteAddress;
            
        } else if ([HXTracerouteTool  isEchoReplyPacket:(char *)buffer pakcetLength:(int)resultLen] && [remoteAddress isEqualToString:self.ipAddress]) {
            
            // 到达目标服务器
            [durations addObject:@(duration)];
            record.currentIP = remoteAddress;
            finished = YES;
            
        } else {
            // 失败
            [durations addObject:[NSNull null]];
            }
        }
    }
    
    record.durations = [durations copy];
    [_results addObject:record];
    
    // 回调每一步的结果
    if (self.stepBlock) {
        self.stepBlock(record);
    }
    NSLog(@"%@", record);
    
    return finished;
}

- (BOOL)validateReply {
    return YES;
}
@end
