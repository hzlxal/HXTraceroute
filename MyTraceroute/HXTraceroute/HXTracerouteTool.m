//
//  HXTracerouteTool.m
//  MyTraceroute
//
//  Created by hzl on 2018/5/27.
//  Copyright © 2018年 hzl. All rights reserved.
//

#import "HXTracerouteTool.h"

//IPv4头部
typedef struct IPv4Header{
    uint8_t versionAndHeaderLength; //版本以及首部长度
    uint8_t serviceType; //服务类型
    uint16_t totalLength; //数据包长度
    uint16_t identifier; //标识
    uint16_t flagsAndFragmentOffset; //标志以及片偏移
    uint8_t timeToLive; //生存时间
    uint8_t protocol; //协议类型
    uint16_t checksum; //首部校验和
    uint8_t sourceAddress[4]; //源地址
    uint8_t destinationAddress[4]; //目标地址
}IPv4Header;

//IPv4编译期检查
__Check_Compile_Time(sizeof(IPv4Header) == 20);
__Check_Compile_Time(offsetof(IPv4Header, versionAndHeaderLength) == 0);
__Check_Compile_Time(offsetof(IPv4Header, serviceType) == 1);
__Check_Compile_Time(offsetof(IPv4Header, totalLength) == 2);
__Check_Compile_Time(offsetof(IPv4Header, identifier) == 4);
__Check_Compile_Time(offsetof(IPv4Header, flagsAndFragmentOffset) == 6);
__Check_Compile_Time(offsetof(IPv4Header, timeToLive) == 8);
__Check_Compile_Time(offsetof(IPv4Header, protocol) == 9);
__Check_Compile_Time(offsetof(IPv4Header, checksum) == 10);
__Check_Compile_Time(offsetof(IPv4Header, sourceAddress) == 12);
__Check_Compile_Time(offsetof(IPv4Header, destinationAddress) == 16);


@implementation HXTracerouteTool

+ (uint16_t)getCheckSumWithBuffer:(const void *)buffer andLength:(size_t)length{
   
    size_t bytesLeft;
    int32_t sum;
    const uint16_t *cursor;
    
    union {
        uint16_t us;
        uint8_t uc[2];
    } last;
    uint16_t answer;
    
    bytesLeft = length;
    sum = 0;
    cursor = buffer;
    
    /*使用32位累加器，顺序累加16位数据，进位保存在高16位*/
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    
    /*如果总字节数为奇数，则处理最后一个字节（将其扩展为字）*/
    if (bytesLeft == 1) {
        last.uc[0] = *(const uint8_t *)cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /*将进位加到低16位，并将本次计算产生的进位也加到低16位*/
    sum = (sum >> 16) + (sum & 0xffff);
    sum += (sum >> 16);
    
    /*结果取反并截低16位为校验和*/
    answer = (uint16_t)~sum;
    
    return answer;
}


+ (struct sockaddr *)getSockaddrWithAddress:(NSString *)address port:(int)port{
    //初始化socketaddr_in
    struct sockaddr_in *addr = (struct sockaddr_in *)malloc(sizeof(struct sockaddr_in));
    memset(addr, 0, sizeof(*addr));
    addr->sin_len = sizeof(addr);
    addr->sin_family = AF_INET;
    addr->sin_port = htons(port);
    
    //将点分十进制的地址转换为二进制地址
    if (inet_pton(AF_INET, address.UTF8String, &(addr->sin_addr.s_addr)) < 0) {
        NSLog(@"创建sockaddr结构体失败");
        return NULL;
    }
    
    return (struct sockaddr *)addr;
}


+ (NSData *)getICMPPacketWithID:(uint16_t)identifier sequenceNumber:(uint16_t)seq{
    NSMutableData *packet;
    ICMPHeader *icmpPtr;
    
    //初始化ICMP头部
    packet = [NSMutableData dataWithLength:sizeof(*icmpPtr)];
    icmpPtr = packet.mutableBytes;
    
    icmpPtr->type = ICMPv4TypeRequest;
    icmpPtr->code = 0;
    
    //将字节序转换为大端序
    icmpPtr->identifier     = OSSwapHostToBigInt16(identifier);
    icmpPtr->sequenceNumber = OSSwapHostToBigInt16(seq);
    
    //进行ICMP校验和的计算
    icmpPtr->checksum = 0;
    icmpPtr->checksum = [self getCheckSumWithBuffer:packet.bytes andLength:packet.length];
    
    return packet;
}


//域名解析
+ (NSArray<NSString *> *)getIPListWithHost:(NSString *)hostname{
    
    NSMutableArray<NSString *> *resolve = [NSMutableArray array];
    CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)hostname);
    
    if (hostRef != NULL) {
         // 开始本地DNS解析
        Boolean result = CFHostStartInfoResolution(hostRef, kCFHostAddresses, NULL);
        
        if (result == true) {
            //本地存储的结果数组（sockaddr类型）
            CFArrayRef addresses = CFHostGetAddressing(hostRef, &result);
           
            //将解析数据中的二进制地址转换为点分十进制的地址
            for(int i = 0; i < CFArrayGetCount(addresses); i++){
                
                CFDataRef saData = (CFDataRef)CFArrayGetValueAtIndex(addresses, i);
                struct sockaddr *addressGeneric = (struct sockaddr *)CFDataGetBytePtr(saData);
                
                if (addressGeneric != NULL) {
                    struct sockaddr_in *remoteAddr = (struct sockaddr_in *)CFDataGetBytePtr(saData);
                    [resolve addObject:[self formatIPv4Address:remoteAddr->sin_addr]];
                }
            }
        }
    }
    
    return [resolve copy];
}


+ (BOOL)isEchoReplyPacket:(char *)packet pakcetLength:(int)len{
    ICMPHeader *icmpPacket = NULL;
    
    icmpPacket = [self unpackICMPv4Packet:packet len:len];
    if (icmpPacket != NULL && icmpPacket->type == ICMPv4TypeReply) {
        return YES;
    }
    
    return NO;
}

+ (BOOL)isTimeOutPacket:(char *)packet packetLength:(int)len{
    ICMPHeader *icmpPacket = NULL;
    
    icmpPacket = [self unpackICMPv4Packet:packet len:len];
    if (icmpPacket != NULL && icmpPacket->type == ICMPv4TypeTimeOut) {
            return YES;
    }
    
    return NO;
}

#pragma mark -- private method
// 从IPv4数据包中解析出ICMP
+ (ICMPHeader *)unpackICMPv4Packet:(char *)packet len:(int)len {
    
    //包长度不合法则丢弃该包
    if (len < (sizeof(IPv4Header) + sizeof(ICMPHeader))) {
        return NULL;
    }
    const struct IPv4Header *ipPtr = (const IPv4Header *)packet;
    
    //判断是否是需要处理的包不是则丢弃
    if ((ipPtr->versionAndHeaderLength & 0xF0) != 0x40 || //获取高4字节即版本号
        ipPtr->protocol != 1) { //获取协议类型
        return NULL;
    }
    
    //获取低4字节即IPv4的头部长度
    size_t ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t);
    if (len < ipHeaderLength + sizeof(ICMPHeader)) {
        return NULL;
    }
    
    //脱去IP头部返回ICMP报文
    return (ICMPHeader *)((char *)packet + ipHeaderLength);
}


//用于将二进制地址转换为点分十进制地址
+ (NSString *)formatIPv4Address:(struct in_addr)ipv4Addr {
    NSString *address = nil;
    char dstStr[INET_ADDRSTRLEN];
    char srcStr[INET_ADDRSTRLEN];
    memcpy(srcStr, &ipv4Addr, sizeof(struct in_addr));
    
    //将二进制地址转为点分十进制地址
    if(inet_ntop(AF_INET, srcStr, dstStr, INET_ADDRSTRLEN) != NULL) {
        address = [NSString stringWithUTF8String:dstStr];
    }
    
    return address;
}
@end
