// Router.h — Metal-accelerated IPv4/IPv6 packet router (Objective-C)
//
// DESIGN:
//   Single packets → CPU trie LPM path (O(32) steps)
//   Batch > 4 packets → Metal GPU path (DIR-24-8 LPM, parallel per-packet)
//   Toggle: router.useMetal = NO forces CPU for benchmarking
#import <Foundation/Foundation.h>
#import "Packet.h"
#import "Interface.h"
#import "RouteTable.h"
#import "MetalAccelerator.h"

@interface Router : NSObject
@property (nonatomic, strong, readonly) RouteTable              *table;
@property (nonatomic, strong, readonly) NSArray<Interface *>    *interfaces;
@property (nonatomic, strong) MetalAccelerator                  *metal;
@property (nonatomic, assign) BOOL useMetal;

- (instancetype)initWithInterfaces:(NSArray<Interface *> *)ifs;
- (void)addConnectedRouteForInterface:(Interface *)iface;
- (void)addStaticRoute:(uint32_t)prefix len:(uint8_t)len
               nextHop:(uint32_t)nh outIf:(NSInteger)ifIdx;
- (Packet *)forwardPacket:(Packet *)pkt;
- (NSArray<Packet *> *)forwardBatch:(NSArray<Packet *> *)pkts;
- (void)dumpStats;
- (void)dumpRoutes;
@end
