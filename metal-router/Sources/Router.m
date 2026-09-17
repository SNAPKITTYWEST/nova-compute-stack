#import "Router.h"
#import "Fragmentation.h"

@interface Router ()
@property (nonatomic, strong) RouteTable *table;
@property (nonatomic, strong) DIRTables *dirTables;
@property (nonatomic, strong) NSArray<Interface *> *interfaces;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, Interface *> *ifMap;
@end

@implementation Router

- (instancetype)initWithInterfaces:(NSArray<Interface *> *)ifs {
    self = [super init];
    if (!self) return nil;
    _interfaces = [ifs copy]; _table = [[RouteTable alloc] init];
    _dirTables = [[DIRTables alloc] initWithRouteTable:_table];
    _neighborCache = [[NeighborCache alloc] init];
    _ifMap = [NSMutableDictionary dictionary];
    for (Interface *i in ifs) { _ifMap[@(i.index)] = i; [self addConnectedRouteForInterface:i]; }
    id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
    _metal = [[MetalAccelerator alloc] initWithDevice:dev];
    _useMetal = _metal.enabled;
    if (_useMetal) { NSLog(@"Metal ready on %@", dev.name); [_metal loadDIRTables:_dirTables]; }
    else NSLog(@"Metal not available – CPU only");
    return self;
}

- (void)addConnectedRouteForInterface:(Interface *)iface {
    uint8_t len = (uint8_t)__builtin_popcount(iface.mask);
    [self.table addRouteIPv4:(iface.ip & iface.mask) prefixLen:len nextHop:0 outInterface:iface.index metric:0];
    RouteEntry e = {0}; e.prefix = iface.ip & iface.mask; e.mask = iface.mask;
    e.prefixLen = len; e.outIfIndex = (int32_t)iface.index;
    [self.dirTables addIPv4Route:e];
    if (self.useMetal) [self.metal loadDIRTables:self.dirTables];
}

- (void)addStaticRouteIPv4:(uint32_t)prefix len:(uint8_t)len nextHop:(uint32_t)nh outIf:(NSInteger)ifIdx {
    [self.table addRouteIPv4:prefix prefixLen:len nextHop:nh outInterface:ifIdx metric:10];
    RouteEntry e = {0}; e.prefix = prefix; e.prefixLen = len; e.nextHop = nh; e.outIfIndex = (int32_t)ifIdx;
    [self.dirTables addIPv4Route:e];
    if (self.useMetal) [self.metal loadDIRTables:self.dirTables];
}

- (Packet *)forwardPacket:(Packet *)pkt {
    if (!pkt.valid || [Fragmentation shouldDropFragment:pkt]) {
        Interface *in = self.ifMap[@(pkt.ingressIfIndex)]; if (in) in.drops++; return nil;
    }
    Interface *inIf = self.ifMap[@(pkt.ingressIfIndex)];
    if (inIf) { inIf.rxPackets++; inIf.rxBytes += pkt.totalLength; }
    if (pkt.ttl <= 1) { if (inIf) inIf.drops++; return nil; }
    for (Interface *iface in self.interfaces) {
        if (!pkt.isIPv6 && iface.ip == pkt.dstIP) { pkt.egressIfIndex = iface.index; pkt.nextHop = 0; return pkt; }
        if (pkt.isIPv6 && [iface isLocalIPv6:pkt.dstIPv6]) { pkt.egressIfIndex = iface.index; return pkt; }
    }
    RouteEntry e = pkt.isIPv6 ? [self.table lookupIPv6:pkt.dstIPv6] : [self.table lookupIPv4:pkt.dstIP];
    if (e.outIfIndex < 0) { if (inIf) inIf.drops++; return nil; }
    Interface *outIf = self.ifMap[@(e.outIfIndex)];
    if (!outIf || !outIf.up) { if (inIf) inIf.drops++; return nil; }
    pkt.egressIfIndex = e.outIfIndex;
    pkt.nextHop = e.nextHop ? e.nextHop : pkt.dstIP;
    pkt.dstMAC = pkt.isIPv6 ?
        [self.neighborCache lookupIPv6:pkt.dstIPv6 ifIndex:e.outIfIndex] :
        [self.neighborCache lookupIPv4:pkt.nextHop ifIndex:e.outIfIndex];
    outIf.txPackets++; outIf.txBytes += pkt.totalLength;
    return pkt;
}

- (NSArray<Packet *> *)forwardBatch:(NSArray<Packet *> *)pkts {
    if (self.useMetal && pkts.count > 8) {
        NSMutableArray *valid = [NSMutableArray array];
        for (Packet *p in pkts) {
            if (!p.valid || [Fragmentation shouldDropFragment:p]) continue;
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
            p.dstMAC = [self.neighborCache lookupIPv4:p.nextHop ?: p.dstIP ifIndex:p.egressIfIndex];
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
