#import "RouteTable.h"
#import "TrieNode.h"

@interface RouteTable ()
@property (nonatomic, strong) TrieNode *root;
@property (nonatomic, strong) NSMutableArray<NSValue *> *flatEntries;
@end

@implementation RouteTable
- (instancetype)init {
    self = [super init];
    if (self) { _root = [[TrieNode alloc] init]; _flatEntries = [NSMutableArray array]; }
    return self;
}
- (uint32_t)maskFromPrefixLen:(uint8_t)len {
    if (len == 0) return 0;
    if (len >= 32) return 0xFFFFFFFF;
    return ~((1u << (32 - len)) - 1);
}
- (void)addRoute:(uint32_t)prefix prefixLen:(uint8_t)len
         nextHop:(uint32_t)nh outInterface:(NSInteger)ifIdx metric:(uint32_t)metric {
    RouteEntry e = {0};
    e.mask = [self maskFromPrefixLen:len];
    e.prefix = prefix & e.mask; e.prefixLen = len;
    e.nextHop = nh; e.outIfIndex = (int32_t)ifIdx; e.metric = metric;
    BOOL replaced = NO;
    for (NSUInteger i = 0; i < self.flatEntries.count; i++) {
        RouteEntry old; [self.flatEntries[i] getValue:&old];
        if (old.prefix == e.prefix && old.prefixLen == e.prefixLen) {
            self.flatEntries[i] = [NSValue valueWithBytes:&e objCType:@encode(RouteEntry)];
            replaced = YES; break;
        }
    }
    if (!replaced) [self.flatEntries addObject:[NSValue valueWithBytes:&e objCType:@encode(RouteEntry)]];
    // Insert into binary trie
    TrieNode *node = self.root;
    for (int i = 31; i >= (int)(32 - len); i--) {
        BOOL bit = (prefix >> i) & 1;
        if (bit) { if (!node.right) node.right = [[TrieNode alloc] init]; node = node.right; }
        else     { if (!node.left)  node.left  = [[TrieNode alloc] init]; node = node.left; }
    }
    node.isLeaf = YES; node.nextHop = nh; node.outIfIndex = (int32_t)ifIdx; node.prefixLen = len;
}
- (void)deleteRoute:(uint32_t)prefix prefixLen:(uint8_t)len {
    uint32_t mask = [self maskFromPrefixLen:len]; prefix &= mask;
    for (NSUInteger i = 0; i < self.flatEntries.count; i++) {
        RouteEntry e; [self.flatEntries[i] getValue:&e];
        if (e.prefix == prefix && e.prefixLen == len) { [self.flatEntries removeObjectAtIndex:i]; return; }
    }
}
- (RouteEntry)lookup:(uint32_t)dstIP {
    RouteEntry best = {0}; best.outIfIndex = -1;
    TrieNode *node = self.root, *lastMatch = nil;
    for (int i = 31; i >= 0 && node; i--) {
        if (node.isLeaf) lastMatch = node;
        BOOL bit = (dstIP >> i) & 1;
        node = bit ? node.right : node.left;
    }
    if (node && node.isLeaf) lastMatch = node;
    if (lastMatch) { best.nextHop = lastMatch.nextHop; best.outIfIndex = lastMatch.outIfIndex; best.prefixLen = lastMatch.prefixLen; }
    return best;
}
- (NSArray<NSValue *> *)allEntries { return [self.flatEntries copy]; }
- (NSUInteger)count { return self.flatEntries.count; }
- (void)dump {
    NSLog(@"=== Routing Table (%lu entries) ===", (unsigned long)self.flatEntries.count);
    for (NSValue *v in self.flatEntries) {
        RouteEntry e; [v getValue:&e];
        char p[INET_ADDRSTRLEN], nh[INET_ADDRSTRLEN];
        struct in_addr pa = { .s_addr = htonl(e.prefix) };
        struct in_addr na = { .s_addr = htonl(e.nextHop) };
        inet_ntop(AF_INET, &pa, p, sizeof(p));
        inet_ntop(AF_INET, &na, nh, sizeof(nh));
        NSLog(@" %s/%u -> nh=%s if=%d metric=%u", p, e.prefixLen, nh, e.outIfIndex, e.metric);
    }
}
@end
