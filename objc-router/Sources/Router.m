#import "Router.h"
#import <Metal/Metal.h>

@interface Router ()
@property (nonatomic, strong) RouteTable *table;
@property (nonatomic, strong) NSArray<Interface *> *interfaces;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, Interface *> *ifMap;
@end

@implementation Router
- (instancetype)initWithInterfaces:(NSArray<Interface *> *)ifs {
    self = [super init];
    if (!self) return nil;
    _interfaces = [ifs copy]; _table = [[RouteTable alloc] init];
    _ifMap = [NSMutableDictionary dictionary];
    for (Interface *i in ifs) { _ifMap[@(i.index)] = i; [self addConnectedRouteForInterface:i]; }
    id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
    _metal = [[MetalAccelerator alloc] initWithDevice:dev];
    _useMetal = _metal.enabled;
    if (_useMetal) { NSLog(@"Metal accelerator ready on %@", dev.name); [self.metal loadRoutes:self.table.allEntries]; }
    else NSLog(@"Metal not available – falling back to CPU only");
    return self;
}
- (void)addConnectedRouteForInterface:(Interface *)iface {
    uint8_t len = (uint8_t)__builtin_popcount(iface.mask);
    [self.table addRoute:(iface.ip & iface.mask) prefixLen:len nextHop:0 outInterface:iface.index metric:0];
    if (self.useMetal) [self.metal loadRoutes:self.table.allEntries];
}
- (void)addStaticRoute:(uint32_t)prefix len:(uint8_t)len nextHop:(uint32_t)nh outIf:(NSInteger)ifIdx {
    [self.table addRoute:prefix prefixLen:len nextHop:nh outInterface:ifIdx metric:10];
    if (self.useMetal) [self.metal loadRoutes:self.table.allEntries];
}
- (Packet *)forwardPacket:(Packet *)pkt {
    if (!pkt.valid) { Interface *in = self.ifMap[@(pkt.ingressIfIndex)]; if (in) in.drops++; return nil; }
    Interface *inIf = self.ifMap[@(pkt.ingressIfIndex)];
    if (inIf) { inIf.rxPackets++; inIf.rxBytes += pkt.totalLength; }
    if (pkt.ttl <= 1) { if (inIf) inIf.drops++; return nil; }
    for (Interface *iface in self.interfaces) {
        if (!pkt.isIPv6 && iface.ip == pkt.dstIP) { pkt.egressIfIndex = iface.index; pkt.nextHop = 0; return pkt; }
    }
    RouteEntry e = [self.table lookup:pkt.dstIP];
    if (e.outIfIndex < 0) { if (inIf) inIf.drops++; return nil; }
    Interface *outIf = self.ifMap[@(e.outIfIndex)];
    if (!outIf || !outIf.up) { if (inIf) inIf.drops++; return nil; }
    pkt.egressIfIndex = e.outIfIndex;
    pkt.nextHop = e.nextHop ? e.nextHop : pkt.dstIP;
    outIf.txPackets++; outIf.txBytes += pkt.totalLength;
    return pkt;
}
- (NSArray<Packet *> *)forwardBatch:(NSArray<Packet *> *)pkts {
    if (self.useMetal && pkts.count > 4) {
        NSMutableArray *valid = [NSMutableArray array];
        for (Packet *p in pkts) {
            if (!p.valid) continue;
            Interface *inIf = self.ifMap[@(p.ingressIfIndex)];
            if (inIf) { inIf.rxPackets++; inIf.rxBytes += p.totalLength; }
            if (p.ttl <= 1) { if (inIf) inIf.drops++; continue; }
            [valid addObject:p];
        }
        NSArray *classified = [self.metal classifyPackets:valid];
        NSMutableArray *forwarded = [NSMutableArray array];
        for (Packet *p in classified) {
            if (p.egressIfIndex < 0) { Interface *in = self.ifMap[@(p.ingressIfIndex)]; if (in) in.drops++; continue; }
            Interface *outIf = self.ifMap[@(p.egressIfIndex)];
            if (!outIf || !outIf.up) { Interface *in = self.ifMap[@(p.ingressIfIndex)]; if (in) in.drops++; continue; }
            outIf.txPackets++; outIf.txBytes += p.totalLength;
            [forwarded addObject:p];
        }
        return forwarded;
    }
    NSMutableArray *out = [NSMutableArray array];
    for (Packet *p in pkts) { Packet *f = [self forwardPacket:p]; if (f) [out addObject:f]; }
    return out;
}
- (void)dumpStats { NSLog(@"=== Interface Statistics ==="); for (Interface *i in self.interfaces) NSLog(@"%@", i); }
- (void)dumpRoutes { [self.table dump]; }
@end
