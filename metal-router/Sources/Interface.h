// Interface.h — Network interface with IPv4 + IPv6 addressing
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Interface : NSObject

@property (nonatomic, assign) NSInteger  index;
@property (nonatomic, copy)   NSString  *name;
@property (nonatomic, assign) uint32_t   ip;           // host order
@property (nonatomic, assign) uint32_t   mask;         // host order
@property (nonatomic, strong, nullable) NSData *ipv6;  // 16 bytes (primary)
@property (nonatomic, assign) uint8_t    ipv6PrefixLen;
@property (nonatomic, assign) uint64_t   mac;          // lower 48 bits
@property (nonatomic, assign) BOOL       up;
@property (nonatomic, assign) uint64_t   rxPackets, txPackets;
@property (nonatomic, assign) uint64_t   rxBytes,    txBytes, drops;

- (instancetype)initWithIndex:(NSInteger)idx name:(NSString *)name
                           ip:(uint32_t)ip mask:(uint32_t)mask;
- (BOOL)isLocalIPv4:(uint32_t)addr;
- (BOOL)isLocalIPv6:(NSData *)addr;
- (NSString *)description;

@end

NS_ASSUME_NONNULL_END
