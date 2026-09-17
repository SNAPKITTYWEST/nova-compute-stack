// RouteTable.h — Binary trie + flat list for GPU upload (Objective-C)
#import <Foundation/Foundation.h>

typedef struct {
    uint32_t prefix;     // host order, already masked
    uint32_t mask;       // host order
    uint8_t  prefixLen;
    uint8_t  _pad[3];
    uint32_t nextHop;    // 0 = directly connected
    int32_t  outIfIndex; // -1 = drop / blackhole
    uint32_t metric;
} RouteEntry;

@interface RouteTable : NSObject
- (void)addRoute:(uint32_t)prefix prefixLen:(uint8_t)len
         nextHop:(uint32_t)nh outInterface:(NSInteger)ifIdx metric:(uint32_t)metric;
- (void)deleteRoute:(uint32_t)prefix prefixLen:(uint8_t)len;
- (RouteEntry)lookup:(uint32_t)dstIP;
- (NSArray<NSValue *> *)allEntries;
- (NSUInteger)count;
- (void)dump;
@end
