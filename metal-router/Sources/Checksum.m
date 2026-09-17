#import "Checksum.h"
#import <arpa/inet.h>

@implementation Checksum

static uint16_t onesComplementSum(const uint8_t *data, NSUInteger len) {
    uint32_t sum = 0;
    for (NSUInteger i = 0; i + 1 < len; i += 2) sum += (data[i] << 8) | data[i+1];
    if (len & 1) sum += data[len-1] << 8;
    while (sum >> 16) sum = (sum & 0xFFFF) + (sum >> 16);
    return (uint16_t)~sum;
}

+ (uint16_t)ipHeaderChecksum:(const uint8_t *)header length:(NSUInteger)len {
    return htons(onesComplementSum(header, len));
}

+ (uint16_t)tcpUdpChecksum:(const uint8_t *)ipHeader
                 transport:(const uint8_t *)transport
             transportLen:(NSUInteger)tlen
                 protocol:(uint8_t)proto
                   isIPv6:(BOOL)isIPv6 {
    uint8_t buf[64 + 2048];
    NSUInteger offset = 0;
    if (!isIPv6) {
        memcpy(buf + offset, ipHeader + 12, 8); offset += 8;
        buf[offset++] = 0; buf[offset++] = proto;
        uint16_t len = htons((uint16_t)tlen); memcpy(buf + offset, &len, 2); offset += 2;
    } else {
        memcpy(buf + offset, ipHeader + 8, 32); offset += 32;
        uint32_t len = htonl((uint32_t)tlen); memcpy(buf + offset, &len, 4); offset += 4;
        buf[offset++] = 0; buf[offset++] = 0; buf[offset++] = 0; buf[offset++] = proto;
    }
    memcpy(buf + offset, transport, tlen);
    if (proto == 6 || proto == 17) {
        NSUInteger csumOff = (proto == 6) ? 16 : 6;
        buf[offset + csumOff] = 0; buf[offset + csumOff + 1] = 0;
    }
    offset += tlen;
    return htons(onesComplementSum(buf, offset));
}

@end
