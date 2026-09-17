#import "Interface.h"
#import <arpa/inet.h>

@implementation Interface

- (instancetype)initWithIndex:(NSInteger)idx name:(NSString *)name
                           ip:(uint32_t)ip mask:(uint32_t)mask {
    self = [super init];
    if (!self) return nil;
    self.index = idx; self.name = [name copy];
    self.ip = ip; self.mask = mask; self.up = YES;
    self.mac = 0; self.ipv6PrefixLen = 0;
    return self;
}

- (BOOL)isLocalIPv4:(uint32_t)addr {
    return (addr & self.mask) == (self.ip & self.mask);
}

- (BOOL)isLocalIPv6:(NSData *)addr {
    if (!self.ipv6 || !addr || addr.length != 16 || self.ipv6.length != 16) return NO;
    NSUInteger bytes = self.ipv6PrefixLen / 8;
    NSUInteger bits  = self.ipv6PrefixLen % 8;
    if (memcmp(self.ipv6.bytes, addr.bytes, bytes) != 0) return NO;
    if (bits == 0) return YES;
    uint8_t mask = (uint8_t)(0xFF << (8 - bits));
    return (((const uint8_t *)self.ipv6.bytes)[bytes] & mask) ==
           (((const uint8_t *)addr.bytes)[bytes] & mask);
}

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
