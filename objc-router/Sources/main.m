// main.m — Demonstration: create router, add routes, forward packets
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <arpa/inet.h>
#import "Router.h"
#import "Packet.h"
#import "Interface.h"

static uint32_t ip(const char *s) {
    struct in_addr a; inet_pton(AF_INET, s, &a); return ntohl(a.s_addr);
}

static NSData *makeIPv4Packet(uint32_t src, uint32_t dst, uint8_t ttl, uint16_t payloadLen) {
    NSMutableData *d = [NSMutableData dataWithLength:20 + payloadLen];
    uint8_t *b = d.mutableBytes;
    b[0] = 0x45; *(uint16_t *)(b+2) = htons(20 + payloadLen);
    b[8] = ttl; b[9] = 17;
    *(uint32_t *)(b+12) = htonl(src); *(uint32_t *)(b+16) = htonl(dst);
    return d;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        Interface *eth0 = [[Interface alloc] initWithIndex:0 name:@"eth0" ip:ip("10.0.0.1")     mask:ip("255.255.255.0")];
        Interface *eth1 = [[Interface alloc] initWithIndex:1 name:@"eth1" ip:ip("192.168.1.1")  mask:ip("255.255.255.0")];
        Interface *eth2 = [[Interface alloc] initWithIndex:2 name:@"eth2" ip:ip("172.16.0.1")   mask:ip("255.255.0.0")];
        Router *r = [[Router alloc] initWithInterfaces:@[eth0, eth1, eth2]];
        [r addStaticRoute:ip("8.8.8.0") len:24 nextHop:ip("192.168.1.254") outIf:1];
        [r addStaticRoute:ip("0.0.0.0") len:0  nextHop:ip("10.0.0.254")    outIf:0];
        [r dumpRoutes];
        // Single packet (CPU path)
        NSData *raw = makeIPv4Packet(ip("10.0.0.50"), ip("8.8.8.8"), 64, 32);
        Packet *p = [[Packet alloc] initWithRawData:raw ingressInterface:0];
        Packet *out = [r forwardPacket:p];
        NSLog(@"Single: %@", out ?: @"DROPPED");
        // Batch (Metal path when available)
        NSMutableArray *batch = [NSMutableArray array];
        for (int i = 0; i < 256; i++) {
            uint32_t dst = (i%3==0) ? ip("8.8.8.8") : (i%3==1) ? ip("172.16.5.10") : ip("1.2.3.4");
            NSData *pktData = makeIPv4Packet(ip("10.0.0.100"), dst, 64, 20);
            [batch addObject:[[Packet alloc] initWithRawData:pktData ingressInterface:0]];
        }
        NSDate *start = [NSDate date];
        NSArray *forwarded = [r forwardBatch:batch];
        NSTimeInterval elapsed = -[start timeIntervalSinceNow];
        NSLog(@"Batch of %lu → %lu forwarded in %.3f ms (Metal=%d)",
              (unsigned long)batch.count, (unsigned long)forwarded.count,
              elapsed * 1000.0, r.useMetal);
        [r dumpStats];
    }
    return 0;
}
