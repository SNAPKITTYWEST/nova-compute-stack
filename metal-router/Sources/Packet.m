#import "Packet.h"
#import "Checksum.h"
#import <arpa/inet.h>

@implementation Packet

- (instancetype)initWithRawData:(NSData *)data ingressInterface:(NSInteger)ifIndex {
    self = [super init];
    if (!self) return nil;
    self.raw = [data copy];
    self.ingressIfIndex = ifIndex;
    self.egressIfIndex = -1;
    self.nextHop = 0;
    self.dstMAC = 0;
    self.valid = NO;
    self.isIPv6 = NO;
    if (data.length < 20) return self;
    const uint8_t *bytes = data.bytes;
    uint8_t version = (bytes[0] >> 4) & 0x0F;
    if (version == 4) {
        uint8_t ihl = bytes[0] & 0x0F;
        if (ihl < 5) return self;
        self.ttl = bytes[8];
        self.protocol = bytes[9];
        self.totalLength = ntohs(*(uint16_t *)(bytes + 2));
        if (self.totalLength > data.length || self.totalLength < 20) return self;
        self.srcIP = ntohl(*(uint32_t *)(bytes + 12));
        self.dstIP = ntohl(*(uint32_t *)(bytes + 16));
        self.valid = YES;
        return self;
    }
    if (version == 6 && data.length >= 40) {
        self.isIPv6 = YES;
        self.ttl = bytes[7];
        self.protocol = bytes[6];
        uint16_t payloadLen = ntohs(*(uint16_t *)(bytes + 4));
        self.totalLength = payloadLen + 40;
        if (self.totalLength > data.length) return self;
        self.srcIPv6 = [data subdataWithRange:NSMakeRange(8, 16)];
        self.dstIPv6 = [data subdataWithRange:NSMakeRange(24, 16)];
        self.valid = YES;
    }
    return self;
}

- (NSData *)serialized {
    if (!self.raw) return nil;
    NSMutableData *out = [self.raw mutableCopy];
    uint8_t *bytes = out.mutableBytes;
    if (!self.isIPv6) {
        if (bytes[8] > 0) bytes[8]--;
        bytes[10] = 0; bytes[11] = 0;
        uint16_t csum = [Checksum ipHeaderChecksum:bytes length:(bytes[0] & 0x0F) * 4];
        *(uint16_t *)(bytes + 10) = csum;
    } else {
        if (bytes[7] > 0) bytes[7]--;
    }
    return out;
}

- (id)copyWithZone:(NSZone *)zone {
    Packet *p = [[Packet alloc] init];
    p.raw = [self.raw copy]; p.isIPv6 = self.isIPv6;
    p.srcIP = self.srcIP; p.dstIP = self.dstIP;
    p.srcIPv6 = [self.srcIPv6 copy]; p.dstIPv6 = [self.dstIPv6 copy];
    p.ttl = self.ttl; p.protocol = self.protocol;
    p.totalLength = self.totalLength; p.valid = self.valid;
    p.ingressIfIndex = self.ingressIfIndex; p.egressIfIndex = self.egressIfIndex;
    p.nextHop = self.nextHop; p.nextHopIPv6 = [self.nextHopIPv6 copy];
    p.dstMAC = self.dstMAC;
    return p;
}

- (NSString *)description {
    if (self.isIPv6) {
        char src[INET6_ADDRSTRLEN], dst[INET6_ADDRSTRLEN];
        inet_ntop(AF_INET6, self.srcIPv6.bytes, src, sizeof(src));
        inet_ntop(AF_INET6, self.dstIPv6.bytes, dst, sizeof(dst));
        return [NSString stringWithFormat:@"IPv6 src=%s dst=%s hop=%u nh=%u len=%u valid=%d ifIn=%ld ifOut=%ld",
                src, dst, self.ttl, self.protocol, self.totalLength, self.valid,
                (long)self.ingressIfIndex, (long)self.egressIfIndex];
    }
    char src[INET_ADDRSTRLEN], dst[INET_ADDRSTRLEN];
    struct in_addr s = { .s_addr = htonl(self.srcIP) };
    struct in_addr d = { .s_addr = htonl(self.dstIP) };
    inet_ntop(AF_INET, &s, src, sizeof(src));
    inet_ntop(AF_INET, &d, dst, sizeof(dst));
    return [NSString stringWithFormat:@"IPv4 src=%s dst=%s ttl=%u proto=%u len=%u valid=%d ifIn=%ld ifOut=%ld nextHop=0x%08x",
            src, dst, self.ttl, self.protocol, self.totalLength, self.valid,
            (long)self.ingressIfIndex, (long)self.egressIfIndex, self.nextHop];
}

@end
