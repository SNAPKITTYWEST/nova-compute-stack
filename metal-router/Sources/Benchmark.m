#import "Benchmark.h"
#import "Packet.h"
#import <arpa/inet.h>

static uint32_t benchIP(const char *s) { struct in_addr a; inet_pton(AF_INET, s, &a); return ntohl(a.s_addr); }

static NSData *makePkt(uint32_t src, uint32_t dst, uint8_t ttl) {
    NSMutableData *d = [NSMutableData dataWithLength:40]; uint8_t *b = d.mutableBytes;
    b[0] = 0x45; *(uint16_t *)(b+2) = htons(40); b[8] = ttl; b[9] = 17;
    *(uint32_t *)(b+12) = htonl(src); *(uint32_t *)(b+16) = htonl(dst);
    return d;
}

void runBenchmark(Router *r, NSUInteger packetCount, NSUInteger iterations) {
    NSMutableArray *batch = [NSMutableArray arrayWithCapacity:packetCount];
    for (NSUInteger i = 0; i < packetCount; i++) {
        uint32_t dst;
        switch (i % 4) {
            case 0: dst = benchIP("8.8.8.8"); break;
            case 1: dst = benchIP("172.16.5.10"); break;
            case 2: dst = benchIP("10.0.0.50"); break;
            default: dst = benchIP("1.2.3.4"); break;
        }
        [batch addObject:[[Packet alloc] initWithRawData:makePkt(benchIP("10.0.0.100"), dst, 64) ingressInterface:0]];
    }
    r.useMetal = NO;
    NSDate *t0 = [NSDate date];
    for (NSUInteger i = 0; i < iterations; i++) [r forwardBatch:batch];
    NSTimeInterval cpuTime = -[t0 timeIntervalSinceNow];
    r.useMetal = YES;
    t0 = [NSDate date];
    for (NSUInteger i = 0; i < iterations; i++) [r forwardBatch:batch];
    NSTimeInterval metalTime = -[t0 timeIntervalSinceNow];
    double total = (double)(packetCount * iterations);
    NSLog(@"=== Benchmark ===");
    NSLog(@"Packets: %lu Iterations: %lu", (unsigned long)packetCount, (unsigned long)iterations);
    NSLog(@"CPU trie: %.3f ms %.2f Mpps", cpuTime*1000, total/(cpuTime*1e6));
    NSLog(@"Metal DIR: %.3f ms %.2f Mpps", metalTime*1000, total/(metalTime*1e6));
    if (metalTime > 0) NSLog(@"Speedup: %.2fx", cpuTime/metalTime);
}
