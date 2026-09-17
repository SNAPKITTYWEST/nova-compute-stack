// Packet.h — IPv4/IPv6 packet wrapper (Objective-C)
#import <Foundation/Foundation.h>

@interface Packet : NSObject <NSCopying>

@property (nonatomic, strong) NSData      *raw;
@property (nonatomic, assign) uint32_t     srcIP;       // host order (IPv4)
@property (nonatomic, assign) uint32_t     dstIP;       // host order (IPv4)
@property (nonatomic, assign) uint8_t      ttl;
@property (nonatomic, assign) uint8_t      protocol;
@property (nonatomic, assign) uint16_t     totalLength;
@property (nonatomic, assign) BOOL         valid;
@property (nonatomic, assign) BOOL         isIPv6;
@property (nonatomic, strong) NSData      *srcIPv6;     // 16 bytes
@property (nonatomic, strong) NSData      *dstIPv6;     // 16 bytes
@property (nonatomic, assign) NSInteger    ingressIfIndex;
@property (nonatomic, assign) NSInteger    egressIfIndex;
@property (nonatomic, assign) uint32_t     nextHop;

- (instancetype)initWithRawData:(NSData *)data ingressInterface:(NSInteger)ifIndex;
- (NSData *)serialized;
- (NSString *)description;

@end
