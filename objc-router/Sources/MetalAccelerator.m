#import "MetalAccelerator.h"

typedef struct { uint32_t prefix,mask; uint8_t prefixLen,_pad[3]; uint32_t nextHop; int32_t outIfIndex; uint32_t metric; } GPURouteEntry;
typedef struct { uint32_t dstIP, _pad; } GPUPacketIn;
typedef struct { int32_t outIfIndex; uint32_t nextHop; } GPUPacketOut;

@interface MetalAccelerator ()
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> queue;
@property (nonatomic, strong) id<MTLComputePipelineState> pipeline;
@property (nonatomic, strong) id<MTLBuffer> routeBuffer;
@property (nonatomic, assign) NSUInteger routeCount;
@end

@implementation MetalAccelerator
- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (!self) return nil;
    _device = device; _enabled = (device != nil);
    if (!_enabled) return self;
    _queue = [device newCommandQueue];
    if (!_queue) { _enabled = NO; return self; }
    NSError *err = nil;
    id<MTLLibrary> library = [device newDefaultLibrary];
    if (!library) library = [device newLibraryWithSource:[self shaderSource] options:nil error:&err];
    if (!library) { NSLog(@"Metal library error: %@", err); _enabled = NO; return self; }
    id<MTLFunction> fn = [library newFunctionWithName:@"lpm_classify"];
    if (!fn) { NSLog(@"Function lpm_classify not found"); _enabled = NO; return self; }
    _pipeline = [device newComputePipelineStateWithFunction:fn error:&err];
    if (!_pipeline) { NSLog(@"Pipeline error: %@", err); _enabled = NO; }
    return self;
}
- (BOOL)loadRoutes:(NSArray<NSValue *> *)entries {
    if (!self.enabled) return NO;
    self.routeCount = entries.count;
    if (self.routeCount == 0) { self.routeBuffer = nil; return YES; }
    NSUInteger bytes = self.routeCount * sizeof(GPURouteEntry);
    self.routeBuffer = [self.device newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    GPURouteEntry *dst = (GPURouteEntry *)self.routeBuffer.contents;
    for (NSUInteger i = 0; i < self.routeCount; i++) {
        RouteEntry e; [entries[i] getValue:&e];
        dst[i] = (GPURouteEntry){e.prefix,e.mask,e.prefixLen,{0,0,0},e.nextHop,e.outIfIndex,e.metric};
    }
    return YES;
}
- (NSArray<Packet *> *)classifyPackets:(NSArray<Packet *> *)packets {
    if (!self.enabled || !self.routeBuffer || packets.count == 0) return packets;
    NSUInteger n = packets.count;
    id<MTLBuffer> inBuf  = [self.device newBufferWithLength:n*sizeof(GPUPacketIn)  options:MTLResourceStorageModeShared];
    id<MTLBuffer> outBuf = [self.device newBufferWithLength:n*sizeof(GPUPacketOut) options:MTLResourceStorageModeShared];
    GPUPacketIn *inPtr = (GPUPacketIn *)inBuf.contents;
    for (NSUInteger i = 0; i < n; i++) inPtr[i].dstIP = packets[i].dstIP;
    id<MTLCommandBuffer> cmd = [self.queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cmd computeCommandEncoder];
    [enc setComputePipelineState:self.pipeline];
    [enc setBuffer:self.routeBuffer offset:0 atIndex:0];
    [enc setBuffer:inBuf offset:0 atIndex:1];
    [enc setBuffer:outBuf offset:0 atIndex:2];
    uint32_t rc = (uint32_t)self.routeCount;
    [enc setBytes:&rc length:sizeof(uint32_t) atIndex:3];
    NSUInteger tgWidth = MIN(self.pipeline.threadExecutionWidth, n);
    [enc dispatchThreads:MTLSizeMake(n,1,1) threadsPerThreadgroup:MTLSizeMake(tgWidth,1,1)];
    [enc endEncoding]; [cmd commit]; [cmd waitUntilCompleted];
    GPUPacketOut *outPtr = (GPUPacketOut *)outBuf.contents;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:n];
    for (NSUInteger i = 0; i < n; i++) {
        Packet *p = [packets[i] copy];
        p.egressIfIndex = outPtr[i].outIfIndex; p.nextHop = outPtr[i].nextHop;
        [result addObject:p];
    }
    return result;
}
- (NSString *)shaderSource {
    return @"#include <metal_stdlib>\nusing namespace metal;\n"
           "struct RouteEntry { uint prefix,mask; uchar prefixLen,pad[3]; uint nextHop; int outIfIndex; uint metric; };\n"
           "struct PacketIn { uint dstIP,pad; };\n"
           "struct PacketOut { int outIfIndex; uint nextHop; };\n"
           "kernel void lpm_classify(device const RouteEntry *routes[[buffer(0)]],device const PacketIn *pkts[[buffer(1)]],device PacketOut *out[[buffer(2)]],constant uint &nRoutes[[buffer(3)]],uint gid[[thread_position_in_grid]]){\n"
           "  uint dst=pkts[gid].dstIP; int bestIf=-1; uint bestNH=0,bestLen=0;\n"
           "  for(uint i=0;i<nRoutes;++i){RouteEntry r=routes[i];if((dst&r.mask)==r.prefix&&r.prefixLen>bestLen){bestLen=r.prefixLen;bestIf=r.outIfIndex;bestNH=r.nextHop;}}\n"
           "  out[gid].outIfIndex=bestIf; out[gid].nextHop=bestNH; }";
}
@end
