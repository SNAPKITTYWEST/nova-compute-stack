// MetalAccelerator.h — DIR-24-8 GPU LPM classification engine
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "DIRTables.h"
#import "Packet.h"

NS_ASSUME_NONNULL_BEGIN

@interface MetalAccelerator : NSObject
- (instancetype)initWithDevice:(nullable id<MTLDevice>)device;
- (BOOL)loadDIRTables:(DIRTables *)dir;
- (NSArray<Packet *> *)classifyPackets:(NSArray<Packet *> *)packets;
@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, assign)   BOOL enabled;
@end

NS_ASSUME_NONNULL_END
