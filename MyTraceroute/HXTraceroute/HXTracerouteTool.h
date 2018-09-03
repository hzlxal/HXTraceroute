//
//  HXTracerouteTool.h
//  MyTraceroute
//
//  Created by hzl on 2018/5/27.
//  Copyright © 2018年 hzl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssertMacros.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <netinet/tcp.h>

@interface HXTracerouteTool : NSObject
#pragma mark -- 外部接口定义
/**
 将域名解析为IP地址

 @param hostname 域名
 @return IP地址表
 */
+ (NSArray<NSString *> *)getIPListWithHost:(NSString *)hostname;

/**
 计算校验和

 @param buffer 指向需校验的数据缓冲区的指针
 @param length 需校验的数据的长度（以字节为单位）
 @return 校验和
 */
+ (uint16_t)getCheckSumWithBuffer:(const void*)buffer andLength:(size_t)length;

/**
 创建sockaddr结构体

 @param address 目的主机地址
 @param port 端口号
 @return sockaddr结构体
 */
+ (struct sockaddr *)getSockaddrWithAddress:(NSString *)address port:(int)port;

/**
 创建ICMP数据包

 @param identifier ID号
 @param seq 序列号
 @return ICMP数据包
 */
+ (NSData *)getICMPPacketWithID:(uint16_t)identifier sequenceNumber:(uint16_t)seq;

/**
 判断是否是回显应答报文

 @param packet 数据包
 @param len 数据包长度
 @return 是否为回显应答报文
 */
+ (BOOL)isEchoReplyPacket:(char *)packet pakcetLength:(int)len;



/**
 判断是否是时间超过报文

 @param packet 数据包
 @param len 数据包长度
 @return 是否为时间超时报文
 */
+ (BOOL)isTimeOutPacket:(char *)packet packetLength:(int)len;


#pragma mark -- ICMP数据格式定义
//ICMP头部
typedef struct ICMPHeader{
    uint8_t type; //类型
    uint8_t code; //代码
    uint16_t checksum; //校验和
    uint16_t identifier; //ID号
    uint16_t sequenceNumber; //序列号
}ICMPHeader;

//ICMP类型部分枚举
typedef NS_ENUM(NSInteger, ICMPv4Type){
    ICMPv4TypeRequest = 8, //回显请求
    ICMPv4TypeReply = 0, //回显应答
    ICMPv4TypeTimeOut = 11 //时间超过
};

//ICMP编译期检查
__Check_Compile_Time(sizeof(ICMPHeader) == 8);
__Check_Compile_Time(offsetof(ICMPHeader, type) == 0);
__Check_Compile_Time(offsetof(ICMPHeader, code) == 1);
__Check_Compile_Time(offsetof(ICMPHeader, checksum) == 2);
__Check_Compile_Time(offsetof(ICMPHeader, identifier) == 4);
__Check_Compile_Time(offsetof(ICMPHeader, sequenceNumber) == 6);

@end
