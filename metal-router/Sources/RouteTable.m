#import "RouteTable.h"
#import "TrieNode.h"
#import <arpa/inet.h>

@interface RouteTable ()
@property (nonatomic, strong) TrieNode *root4;
@property (nonatomic, strong) TrieNode *root6;
@property (nonatomic, strong) NSMutableArray<NSValue *> *flat4;
@property (nonatomic, strong) NSMutableArray<NSValue *> *flat6;
@end

@implementation RouteTable

- (instancetype)init {
    self = [super init];
    if (self) {
        _root4 = [[TrieNode alloc] init]; _root6 = [[TrieNode alloc] init];
        _flat4 = [NSMutableArray array]; _flat6 = [NSMutableArray array];
    }
    return self;
}

- (uint32_t)maskFromLen:(uint8_t)len {
    if (len == 0) return 0; if (len >= 32) return 0xFFFFFFFF;
    return ~((1u << (32 - len)) - 1);
}

- (void)addRouteIPv4:(uint32_t)prefix prefixLen:(uint8_t)len nextHop:(uint32_t)nh
       outInterface:(NSInteger)ifIdx metric:(uint32_t)metric {
    RouteEntry e = {0};
    e.mask = [self maskFromLen:len]; e.prefix = prefix & e.mask;
    e.prefixLen = len; e.nextHop = nh; e.outIfIndex = (int32_t)ifIdx; e.metric = metric;
    BOOL replaced = NO;
    for (NSUInteger i = 0; i < self.flat4.count; i++) {
        RouteEntry old; [self.flat4[i] getValue:&old];
        if (old.prefix == e.prefix && old.prefixLen == e.prefixLen) {
            self.flat4[i] = [NSValue valueWithBytes:&e objCType:@encode(RouteEntry)]; replaced = YES; break;
        }
    }
    if (!replaced) [self.flat4 addObject:[NSValue valueWithBytes:&e objCType:@encode(RouteEntry)]];
    TrieNode *node = self.root4;
    for (int i = 31; i >= (int)(32 - len); i--) {
        BOOL bit = (prefix >> i) & 1;
        if (bit) { if (!node.right) node.right = [[TrieNode alloc] init]; node = node.right; }
        else     { if (!node.left)  node.left  = [[TrieNode alloc] init]; node = node.left; }
    }
    node.isLeaf = YES; node.nextHop = nh; node.outIfIndex = (int32_t)ifIdx; node.prefixLen = len;
}

- (void)addRouteIPv6:(NSData *)prefix prefixLen:(uint8_t)len nextHop:(NSData *)nh
       outInterface:(NSInteger)ifIdx metric:(uint32_t)metric {
    if (prefix.length != 16) return;
    RouteEntry e = {0}; e.prefixLen = len; e.isIPv6 = 1; e.outIfIndex = (int32_t)ifIdx; e.metric = metric;
    [self.flat6 addObject:[NSValue valueWithBytes:&e objCType:@encode(RouteEntry)]];
    TrieNode *node = self.root6;
    const uint8_t *p = prefix.bytes;
    for (int i = 0; i < len; i++) {
        int byteIdx = i / 8, bitIdx = 7 - (i % 8);
        BOOL bit = (p[byteIdx] >> bitIdx) & 1;
        if (bit) { if (!node.right) node.right = [[TrieNode alloc] init]; node = node.right; }
        else     { if (!node.left)  node.left  = [[TrieNode alloc] init]; node = node.left; }
    }
    node.isLeaf = YES; node.nextHopIPv6 = [nh copy]; node.outIfIndex = (int32_t)ifIdx; node.prefixLen = len;
}

- (void)deleteRouteIPv4:(uint32_t)prefix prefixLen:(uint8_t)len {
    uint32_t mask = [self maskFromLen:len]; prefix &= mask;
    for (NSUInteger i = 0; i < self.flat4.count; i++) {
        RouteEntry e; [self.flat4[i] getValue:&e];
        if (e.prefix == prefix && e.prefixLen == len) { [self.flat4 removeObjectAtIndex:i]; return; }
    }
}

- (void)deleteRouteIPv6:(NSData *)prefix prefixLen:(uint8_t)len {}

- (RouteEntry)lookupIPv4:(uint32_t)dstIP {
    RouteEntry best = {0}; best.outIfIndex = -1;
    TrieNode *node = self.root4, *lastMatch = nil;
    for (int i = 31; i >= 0 && node; i--) {
        if (node.isLeaf) lastMatch = node;
        BOOL bit = (dstIP >> i) & 1;
        node = bit ? node.right : node.left;
    }
    if (node && node.isLeaf) lastMatch = node;
    if (lastMatch) { best.nextHop = lastMatch.nextHop; best.outIfIndex = lastMatch.outIfIndex; best.prefixLen = lastMatch.prefixLen; }
    return best;
}

- (RouteEntry)lookupIPv6:(NSData *)dstIP {
    RouteEntry best = {0}; best.outIfIndex = -1;
    if (dstIP.length != 16) return best;
    TrieNode *node = self.root6, *lastMatch = nil;
    const uint8_t *p = dstIP.bytes;
    for (int i = 0; i < 128 && node; i++) {
        if (node.isLeaf) lastMatch = node;
        int byteIdx = i / 8, bitIdx = 7 - (i % 8);
        BOOL bit = (p[byteIdx] >> bitIdx) & 1;
        node = bit ? node.right : node.left;
    }
    if (node && node.isLeaf) lastMatch = node;
    if (lastMatch) { best.outIfIndex = lastMatch.outIfIndex; best.prefixLen = lastMatch.prefixLen; }
    return best;
}

- (NSArray<NSValue *> *)allIPv4Entries { return [self.flat4 copy]; }
- (NSArray<NSValue *> *)allIPv6Entries { return [self.flat6 copy]; }
- (NSUInteger)count { return self.flat4.count + self.flat6.count; }

- (void)dump {
    NSLog(@"=== IPv4 Routing Table (%lu entries) ===", (unsigned long)self.flat4.count);
    for (NSValue *v in self.flat4) {
        RouteEntry e; [v getValue:&e];
        char p[INET_ADDRSTRLEN], nh[INET_ADDRSTRLEN];
        struct in_addr pa = { .s_addr = htonl(e.prefix) };
        struct in_addr na = { .s_addr = htonl(e.nextHop) };
        inet_ntop(AF_INET, &pa, p, sizeof(p));
        inet_ntop(AF_INET, &na, nh, sizeof(nh));
        NSLog(@" %s/%u -> nh=%s if=%d metric=%u", p, e.prefixLen, nh, e.outIfIndex, e.metric);
    }
    NSLog(@"=== IPv6 Routing Table (%lu entries) ===", (unsigned long)self.flat6.count);
}

@end
