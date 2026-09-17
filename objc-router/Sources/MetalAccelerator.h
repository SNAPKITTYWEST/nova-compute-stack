// MetalAccelerator.h — Metal GPU LPM classification engine (Objective-C)
//
// Loads routing table into GPU memory, classifies batches of packets
// in parallel using the DIR-24-8 two-level trie shader.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "RouteTable.h"
#import "Packet.h"

@interface MetalAccelerator : NSObject
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (BOOL)loadRoutes:(NSArray<NSValue *> *)entries;
- (NSArray<Packet *> *)classifyPackets:(NSArray<Packet *> *)packets;
@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, assign)   BOOL enabled;
@end
