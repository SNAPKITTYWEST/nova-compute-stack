#import "NeighborCache.h"
#import <arpa/inet.h>

@implementation NeighborEntry
@end

@interface NeighborCache ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NeighborEntry *> *cache;
@end

@implementation NeighborCache

- (instancetype)init { self = [super init]; if (self) _cache = [NSMutableDictionary dictionary]; return self; }

- (NSString *)keyForIPv4:(uint32_t)ip ifIndex:(NSInteger)idx {
    return [NSString stringWithFormat:@"4:%u:%ld", ip, (long)idx];
}

- (NSString *)keyForIPv6:(NSData *)ip6 ifIndex:(NSInteger)idx {
    const uint8_t *b = ip6.bytes;
    return [NSString stringWithFormat:@"6:%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x:%ld",
            b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7],b[8],b[9],b[10],b[11],b[12],b[13],b[14],b[15],(long)idx];
}

- (void)addIPv4:(uint32_t)ip mac:(uint64_t)mac ifIndex:(NSInteger)idx timeout:(NSTimeInterval)t {
    NeighborEntry *e = [[NeighborEntry alloc] init];
    e.mac = mac; e.ifIndex = idx; e.expiry = [NSDate date].timeIntervalSince1970 + t;
    self.cache[[self keyForIPv4:ip ifIndex:idx]] = e;
}

- (void)addIPv6:(NSData *)ip6 mac:(uint64_t)mac ifIndex:(NSInteger)idx timeout:(NSTimeInterval)t {
    NeighborEntry *e = [[NeighborEntry alloc] init];
    e.ip = [ip6 copy]; e.mac = mac; e.ifIndex = idx; e.expiry = [NSDate date].timeIntervalSince1970 + t;
    self.cache[[self keyForIPv6:ip6 ifIndex:idx]] = e;
}

- (uint64_t)lookupIPv4:(uint32_t)ip ifIndex:(NSInteger)idx {
    NSString *key = [self keyForIPv4:ip ifIndex:idx];
    NeighborEntry *e = self.cache[key];
    if (!e) return 0;
    if (e.expiry < [NSDate date].timeIntervalSince1970) { [self.cache removeObjectForKey:key]; return 0; }
    return e.mac;
}

- (uint64_t)lookupIPv6:(NSData *)ip6 ifIndex:(NSInteger)idx {
    NSString *key = [self keyForIPv6:ip6 ifIndex:idx];
    NeighborEntry *e = self.cache[key];
    if (!e) return 0;
    if (e.expiry < [NSDate date].timeIntervalSince1970) { [self.cache removeObjectForKey:key]; return 0; }
    return e.mac;
}

- (void)ageOut {
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    for (NSString *k in self.cache.allKeys) { if (self.cache[k].expiry < now) [self.cache removeObjectForKey:k]; }
}

- (void)dump {
    NSLog(@"=== Neighbor Cache (%lu entries) ===", (unsigned long)self.cache.count);
    for (NeighborEntry *e in self.cache.allValues) NSLog(@" if=%ld mac=0x%012llx", (long)e.ifIndex, e.mac);
}

@end
