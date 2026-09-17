#import "Interface.h"
#import <arpa/inet.h>

@implementation Interface
- (instancetype)initWithIndex:(NSInteger)idx name:(NSString *)name
                           ip:(uint32_t)ip mask:(uint32_t)mask {
    self = [super init];
    if (!self) return nil;
    self.index = idx; self.name = [name copy];
    self.ip = ip; self.mask = mask; self.up = YES;
    return self;
}
- (BOOL)isLocal:(uint32_t)addr { return (addr & self.mask) == (self.ip & self.mask); }
- (NSString *)description {
    char ipstr[INET_ADDRSTRLEN];
    struct in_addr a = { .s_addr = htonl(self.ip) };
    inet_ntop(AF_INET, &a, ipstr, sizeof(ipstr));
    return [NSString stringWithFormat:@"%ld:%@ %@/%d up=%d rx=%llu tx=%llu drops=%llu",
            (long)self.index, self.name, @(ipstr),
            __builtin_popcount(self.mask), self.up,
            self.rxPackets, self.txPackets, self.drops];
}
@end
