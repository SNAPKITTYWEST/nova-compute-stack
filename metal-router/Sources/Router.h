// Router.h — Production dual-stack Metal-accelerated IP router
//
// Forwarding paths:
//   Single packet  → CPU trie LPM (binary trie, O(32) IPv4 / O(128) IPv6)
//   Batch > 8      → Metal GPU DIR-24-8 (O(1)/O(2) per packet, parallel)
//
// Features: IPv4 fragmentation drop, neighbor cache (ARP+NDP), MAC rewrite,
//           incremental DIR-24-8, ControlPlane text commands
#import <Foundation/Foundation.h>
#import "Packet.h"
#import "Interface.h"
#import "RouteTable.h"
#import "DIRTables.h"
#import "MetalAccelerator.h"
#import "NeighborCache.h"

NS_ASSUME_NONNULL_BEGIN

@interface Router : NSObject

@property (nonatomic, strong, readonly) RouteTable           *table;
@property (nonatomic, strong, readonly) DIRTables            *dirTables;
@property (nonatomic, strong, readonly) NSArray<Interface *> *interfaces;
@property (nonatomic, strong) MetalAccelerator               *metal;
@property (nonatomic, strong) NeighborCache                  *neighborCache;
@property (nonatomic, assign) BOOL useMetal;

- (instancetype)initWithInterfaces:(NSArray<Interface *> *)ifs;
- (void)addConnectedRouteForInterface:(Interface *)iface;
- (void)addStaticRouteIPv4:(uint32_t)prefix len:(uint8_t)len
                   nextHop:(uint32_t)nh outIf:(NSInteger)ifIdx;
- (Packet *)forwardPacket:(Packet *)pkt;
- (NSArray<Packet *> *)forwardBatch:(NSArray<Packet *> *)pkts;
- (void)dumpStats;
- (void)dumpRoutes;

@end

NS_ASSUME_NONNULL_END
