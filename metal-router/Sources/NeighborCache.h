// NeighborCache.h — ARP (IPv4) + NDP (IPv6) neighbor table with TTL-based aging
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NeighborEntry : NSObject
@property (nonatomic, strong) NSData       *ip;         // 4 or 16 bytes
@property (nonatomic, assign) uint64_t      mac;        // lower 48 bits
@property (nonatomic, assign) NSTimeInterval expiry;
@property (nonatomic, assign) NSInteger     ifIndex;
@property (nonatomic, assign) BOOL          isRouter;
@end

@interface NeighborCache : NSObject
- (void)addIPv4:(uint32_t)ip mac:(uint64_t)mac ifIndex:(NSInteger)idx timeout:(NSTimeInterval)t;
- (void)addIPv6:(NSData *)ip6 mac:(uint64_t)mac ifIndex:(NSInteger)idx timeout:(NSTimeInterval)t;
- (uint64_t)lookupIPv4:(uint32_t)ip ifIndex:(NSInteger)idx; // 0 = miss
- (uint64_t)lookupIPv6:(NSData *)ip6 ifIndex:(NSInteger)idx;
- (void)ageOut;
- (void)dump;
@end

NS_ASSUME_NONNULL_END
