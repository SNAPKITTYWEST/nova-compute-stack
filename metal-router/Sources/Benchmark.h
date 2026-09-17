// Benchmark.h — CPU trie vs Metal DIR-24-8 benchmark harness
#import <Foundation/Foundation.h>
#import "Router.h"

NS_ASSUME_NONNULL_BEGIN
void runBenchmark(Router *r, NSUInteger packetCount, NSUInteger iterations);
NS_ASSUME_NONNULL_END
