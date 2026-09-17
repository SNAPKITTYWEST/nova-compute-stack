// Packet.h — Dual-stack IPv4/IPv6 packet wrapper with checksum rewrite support
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Packet : NSObject <NSCopying>

@property (nonatomic, strong) NSData      *raw;
@property (nonatomic, assign) BOOL         isIPv6;
@property (nonatomic, assign) uint32_t     srcIP;          // host order (IPv4)
@property (nonatomic, assign) uint32_t     dstIP;          // host order (IPv4)
@property (nonatomic, strong, nullable) NSData *srcIPv6;   // 16 bytes
@property (nonatomic, strong, nullable) NSData *dstIPv6;   // 16 bytes
@property (nonatomic, assign) uint8_t      ttl;            // or Hop Limit
@property (nonatomic, assign) uint8_t      protocol;       // or Next Header
@property (nonatomic, assign) uint16_t     totalLength;
@property (nonatomic, assign) BOOL         valid;
@property (nonatomic, assign) NSInteger    ingressIfIndex;
@property (nonatomic, assign) NSInteger    egressIfIndex;
@property (nonatomic, assign) uint32_t     nextHop;        // IPv4 next hop (host order)
@property (nonatomic, strong, nullable) NSData *nextHopIPv6;
@property (nonatomic, assign) uint64_t     dstMAC;         // filled after neighbor lookup

- (instancetype)initWithRawData:(NSData *)data ingressInterface:(NSInteger)ifIndex;
- (NSData *)serialized; // rewrites TTL + IP header checksum
- (NSString *)description;

@end

NS_ASSUME_NONNULL_END
