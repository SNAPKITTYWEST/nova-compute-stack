#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "Router.h"
#import "Packet.h"
#import "Interface.h"
#import "ControlPlane.h"
#import "Benchmark.h"
#import <arpa/inet.h>

static uint32_t ip(const char *s) { struct in_addr a; inet_pton(AF_INET, s, &a); return ntohl(a.s_addr); }

static NSData *makeIPv4Packet(uint32_t src, uint32_t dst, uint8_t ttl, uint16_t payloadLen) {
    NSMutableData *d = [NSMutableData dataWithLength:20 + payloadLen]; uint8_t *b = d.mutableBytes;
    b[0] = 0x45; *(uint16_t *)(b+2) = htons(20 + payloadLen); b[8] = ttl; b[9] = 17;
    *(uint32_t *)(b+12) = htonl(src); *(uint32_t *)(b+16) = htonl(dst);
    return d;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        Interface *eth0 = [[Interface alloc] initWithIndex:0 name:@"eth0" ip:ip("10.0.0.1")     mask:ip("255.255.255.0")];
        Interface *eth1 = [[Interface alloc] initWithIndex:1 name:@"eth1" ip:ip("192.168.1.1")  mask:ip("255.255.255.0")];
        Interface *eth2 = [[Interface alloc] initWithIndex:2 name:@"eth2" ip:ip("172.16.0.1")   mask:ip("255.255.0.0")];
        Router *r = [[Router alloc] initWithInterfaces:@[eth0, eth1, eth2]];
        [r addStaticRouteIPv4:ip("8.8.8.0") len:24 nextHop:ip("192.168.1.254") outIf:1];
        [r addStaticRouteIPv4:ip("0.0.0.0") len:0  nextHop:ip("10.0.0.254")    outIf:0];
        [r.neighborCache addIPv4:ip("192.168.1.254") mac:0x001122334455 ifIndex:1 timeout:300];
        [r dumpRoutes];
        NSData *raw = makeIPv4Packet(ip("10.0.0.50"), ip("8.8.8.8"), 64, 32);
        Packet *p = [[Packet alloc] initWithRawData:raw ingressInterface:0];
        NSLog(@"Single: %@", [r forwardPacket:p] ?: @"DROPPED");
        ControlPlane *cp = [[ControlPlane alloc] initWithRouter:r];
        NSLog(@"%@", [cp executeCommand:@"show stats"]);
        NSLog(@"%@", [cp executeCommand:@"add 10.1.0.0/16 via 192.168.1.1 dev 1"]);
        runBenchmark(r, 4096, 20);
        [r dumpStats];
    }
    return 0;
}
