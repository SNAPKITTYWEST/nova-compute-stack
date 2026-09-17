// Fragmentation.h — IPv4 fragment detection and drop policy
#import <Foundation/Foundation.h>
#import "Packet.h"

NS_ASSUME_NONNULL_BEGIN

@interface Fragmentation : NSObject
+ (BOOL)isFragment:(Packet *)pkt;
+ (BOOL)shouldDropFragment:(Packet *)pkt;
@end

NS_ASSUME_NONNULL_END
