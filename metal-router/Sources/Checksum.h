// Checksum.h — One's complement IP/TCP/UDP checksum helpers
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Checksum : NSObject
+ (uint16_t)ipHeaderChecksum:(const uint8_t *)header length:(NSUInteger)len;
+ (uint16_t)tcpUdpChecksum:(const uint8_t *)ipHeader
                 transport:(const uint8_t *)transport
             transportLen:(NSUInteger)tlen
                 protocol:(uint8_t)proto
                   isIPv6:(BOOL)isIPv6;
@end

NS_ASSUME_NONNULL_END
