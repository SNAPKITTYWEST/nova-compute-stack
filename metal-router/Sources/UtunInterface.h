// UtunInterface.h — macOS utun tunnel for real packet I/O
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UtunInterface : NSObject
@property (nonatomic, assign) int fd;
@property (nonatomic, assign) NSInteger ifIndex;
@property (nonatomic, copy, nullable) NSString *name; // e.g. utun3

- (BOOL)openWithUnit:(int)unit;   // 0 = kernel assigns
- (nullable NSData *)readPacket;  // raw IP packet (AF header stripped)
- (BOOL)writePacket:(NSData *)pkt isIPv6:(BOOL)isIPv6;
- (void)close;
@end

NS_ASSUME_NONNULL_END
