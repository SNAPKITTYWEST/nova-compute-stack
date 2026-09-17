#import "Fragmentation.h"

@implementation Fragmentation

+ (BOOL)isFragment:(Packet *)pkt {
    if (pkt.isIPv6 || !pkt.valid || pkt.raw.length < 20) return NO;
    const uint8_t *b = pkt.raw.bytes;
    uint16_t frag = ntohs(*(uint16_t *)(b + 6));
    uint16_t offset = frag & 0x1FFF;
    BOOL mf = (frag & 0x2000) != 0;
    return (offset != 0) || mf;
}

+ (BOOL)shouldDropFragment:(Packet *)pkt {
    if (![self isFragment:pkt]) return NO;
    const uint8_t *b = pkt.raw.bytes;
    uint16_t frag = ntohs(*(uint16_t *)(b + 6));
    return (frag & 0x1FFF) != 0; // drop non-first fragments
}

@end
