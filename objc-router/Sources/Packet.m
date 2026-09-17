#import "Packet.h"
#import <arpa/inet.h>

@implementation Packet

- (instancetype)initWithRawData:(NSData *)data ingressInterface:(NSInteger)ifIndex {
    self = [super init];
    if (!self) return nil;
    self.raw = [data copy];
    self.ingressIfIndex = ifIndex;
    self.egressIfIndex = -1;
    self.nextHop = 0;
    self.valid = NO;
    self.isIPv6 = NO;
    if (data.length < 20) return self;
    const uint8_t *bytes = data.bytes;
    uint8_t version = (bytes[0] >> 4) & 0x0F;
    if (version == 6 && data.length >= 40) {
        self.isIPv6 = YES;
        self.srcIPv6 = [data subdataWithRange:NSMakeRange(8, 16)];
        self.dstIPv6 = [data subdataWithRange:NSMakeRange(24, 16)];
        self.ttl = bytes[7];
        self.protocol = bytes[6];
        self.totalLength = ntohs(*(uint16_t *)(bytes + 4)) + 40;
        self.valid = YES;
        return self;
    }
    uint8_t ihl = bytes[0] & 0x0F;
    if (version != 4 || ihl < 5) return self;
    self.ttl = bytes[8];
    self.protocol = bytes[9];
    self.totalLength = ntohs(*(uint16_t *)(bytes + 2));
    if (self.totalLength > data.length) return self;
    self.srcIP = ntohl(*(uint32_t *)(bytes + 12));
    self.dstIP = ntohl(*(uint32_t *)(bytes + 16));
    self.valid = YES;
    return self;
}

- (NSData *)serialized { return self.raw ? [self.raw mutableCopy] : nil; }

- (id)copyWithZone:(NSZone *)zone {
    Packet *p = [[Packet alloc] init];
    p.raw = [self.raw copy]; p.srcIP = self.srcIP; p.dstIP = self.dstIP;
    p.ttl = self.ttl; p.protocol = self.protocol;
    p.totalLength = self.totalLength; p.valid = self.valid;
    p.isIPv6 = self.isIPv6; p.srcIPv6 = self.srcIPv6; p.dstIPv6 = self.dstIPv6;
    p.ingressIfIndex = self.ingressIfIndex; p.egressIfIndex = self.egressIfIndex;
    p.nextHop = self.nextHop;
    return p;
}

- (NSString *)description {
    if (self.isIPv6) return [NSString stringWithFormat:@"Packet IPv6 ttl=%u proto=%u len=%u valid=%d ifIn=%ld ifOut=%ld",
                             self.ttl, self.protocol, self.totalLength, self.valid,
                             (long)self.ingressIfIndex, (long)self.egressIfIndex];
    char src[INET_ADDRSTRLEN], dst[INET_ADDRSTRLEN];
    struct in_addr s = { .s_addr = htonl(self.srcIP) };
    struct in_addr d = { .s_addr = htonl(self.dstIP) };
    inet_ntop(AF_INET, &s, src, sizeof(src));
    inet_ntop(AF_INET, &d, dst, sizeof(dst));
    return [NSString stringWithFormat:@"Packet src=%s dst=%s ttl=%u proto=%u len=%u valid=%d ifIn=%ld ifOut=%ld nextHop=0x%08x",
            src, dst, self.ttl, self.protocol, self.totalLength, self.valid,
            (long)self.ingressIfIndex, (long)self.egressIfIndex, self.nextHop];
}

@end
