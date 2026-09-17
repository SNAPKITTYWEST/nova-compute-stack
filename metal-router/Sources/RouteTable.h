// RouteTable.h — Dual-stack IPv4/IPv6 route table (binary trie + flat GPU upload list)
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    uint32_t prefix;     // host order, already masked (IPv4)
    uint32_t mask;
    uint8_t  prefixLen;
    uint8_t  isIPv6;     // 0 = IPv4, 1 = IPv6
    uint8_t  _pad[2];
    uint32_t nextHop;    // IPv4 (0 = directly connected)
    int32_t  outIfIndex; // -1 = drop
    uint32_t metric;
} RouteEntry;

@interface RouteTable : NSObject

- (void)addRouteIPv4:(uint32_t)prefix prefixLen:(uint8_t)len
             nextHop:(uint32_t)nh outInterface:(NSInteger)ifIdx metric:(uint32_t)metric;
- (void)addRouteIPv6:(NSData *)prefix prefixLen:(uint8_t)len
             nextHop:(nullable NSData *)nh outInterface:(NSInteger)ifIdx metric:(uint32_t)metric;
- (void)deleteRouteIPv4:(uint32_t)prefix prefixLen:(uint8_t)len;
- (void)deleteRouteIPv6:(NSData *)prefix prefixLen:(uint8_t)len;

- (RouteEntry)lookupIPv4:(uint32_t)dstIP;
- (RouteEntry)lookupIPv6:(NSData *)dstIP;

- (NSArray<NSValue *> *)allIPv4Entries;
- (NSArray<NSValue *> *)allIPv6Entries;
- (NSUInteger)count;
- (void)dump;

@end

NS_ASSUME_NONNULL_END
