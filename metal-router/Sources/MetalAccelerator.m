#import "MetalAccelerator.h"

typedef struct { uint32_t dstIP; } GPUPacketIn;
typedef struct { int32_t outIfIndex; uint32_t nextHop; } GPUPacketOut;

@interface MetalAccelerator ()
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> queue;
@property (nonatomic, strong) id<MTLComputePipelineState> pipeline;
@property (nonatomic, strong) id<MTLBuffer> tbl24Buffer;
@property (nonatomic, strong) id<MTLBuffer> tbl8Buffer;
@end

@implementation MetalAccelerator

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (!self) return nil;
    _device = device ?: MTLCreateSystemDefaultDevice();
    _enabled = (_device != nil);
    if (!_enabled) return self;
    _queue = [_device newCommandQueue];
    if (!_queue) { _enabled = NO; return self; }
    NSError *err = nil;
    id<MTLLibrary> library = [_device newDefaultLibrary];
    if (!library) {
        NSString *src = [self embeddedShaderSource];
        library = [_device newLibraryWithSource:src options:nil error:&err];
        if (!library) { NSLog(@"Metal library error: %@", err); _enabled = NO; return self; }
    }
    id<MTLFunction> fn = [library newFunctionWithName:@"dir24_8_classify"];
    if (!fn) { NSLog(@"Function dir24_8_classify not found"); _enabled = NO; return self; }
    _pipeline = [_device newComputePipelineStateWithFunction:fn error:&err];
    if (!_pipeline) { NSLog(@"Pipeline error: %@", err); _enabled = NO; }
    return self;
}

- (BOOL)loadDIRTables:(DIRTables *)dir {
    if (!self.enabled) return NO;
    self.tbl24Buffer = [self.device newBufferWithBytes:dir.tbl24.bytes length:dir.tbl24.length options:MTLResourceStorageModeShared];
    if (dir.tbl8.length > 0)
        self.tbl8Buffer = [self.device newBufferWithBytes:dir.tbl8.bytes length:dir.tbl8.length options:MTLResourceStorageModeShared];
    else
        self.tbl8Buffer = [self.device newBufferWithLength:256*sizeof(uint64_t) options:MTLResourceStorageModeShared]; // empty placeholder
    return YES;
}

- (NSArray<Packet *> *)classifyPackets:(NSArray<Packet *> *)packets {
    if (!self.enabled || !self.tbl24Buffer || packets.count == 0) return packets;
    NSMutableArray *ipv4 = [NSMutableArray array];
    NSMutableArray *indices = [NSMutableArray array];
    for (NSUInteger i = 0; i < packets.count; i++) {
        Packet *p = packets[i];
        if (!p.isIPv6 && p.valid) { [ipv4 addObject:p]; [indices addObject:@(i)]; }
    }
    if (ipv4.count == 0) return packets;
    NSUInteger n = ipv4.count;
    id<MTLBuffer> inBuf  = [self.device newBufferWithLength:n*sizeof(GPUPacketIn)  options:MTLResourceStorageModeShared];
    id<MTLBuffer> outBuf = [self.device newBufferWithLength:n*sizeof(GPUPacketOut) options:MTLResourceStorageModeShared];
    GPUPacketIn *inPtr = (GPUPacketIn *)inBuf.contents;
    for (NSUInteger i = 0; i < n; i++) inPtr[i].dstIP = [ipv4[i] dstIP];
    id<MTLCommandBuffer> cmd = [self.queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cmd computeCommandEncoder];
    [enc setComputePipelineState:self.pipeline];
    [enc setBuffer:self.tbl24Buffer offset:0 atIndex:0];
    [enc setBuffer:self.tbl8Buffer  offset:0 atIndex:1];
    [enc setBuffer:inBuf  offset:0 atIndex:2];
    [enc setBuffer:outBuf offset:0 atIndex:3];
    NSUInteger tgWidth = MIN(self.pipeline.threadExecutionWidth, n);
    [enc dispatchThreads:MTLSizeMake(n,1,1) threadsPerThreadgroup:MTLSizeMake(tgWidth,1,1)];
    [enc endEncoding]; [cmd commit]; [cmd waitUntilCompleted];
    GPUPacketOut *outPtr = (GPUPacketOut *)outBuf.contents;
    NSMutableArray *result = [packets mutableCopy];
    for (NSUInteger i = 0; i < n; i++) {
        NSUInteger origIdx = [indices[i] unsignedIntegerValue];
        Packet *p = [result[origIdx] copy];
        p.egressIfIndex = outPtr[i].outIfIndex; p.nextHop = outPtr[i].nextHop;
        result[origIdx] = p;
    }
    return result;
}

- (NSString *)embeddedShaderSource {
    return @"#include <metal_stdlib>\nusing namespace metal;\n"
           "struct DIREntry{uint nextHop;int outIfIndex;ushort secondaryIndex;uchar prefixLen,flags;};\n"
           "struct PacketIn{uint dstIP;};\nstruct PacketOut{int outIfIndex;uint nextHop;};\n"
           "kernel void dir24_8_classify(device const DIREntry*tbl24[[buffer(0)]],device const DIREntry*tbl8[[buffer(1)]],device const PacketIn*pkts[[buffer(2)]],device PacketOut*out[[buffer(3)]],uint gid[[thread_position_in_grid]]){"
           "uint dst=pkts[gid].dstIP;DIREntry e=tbl24[dst>>8];"
           "if(e.secondaryIndex!=0xFFFF){DIREntry s=tbl8[e.secondaryIndex*256+(dst&0xFF)];if(s.outIfIndex>=0)e=s;}"
           "out[gid].outIfIndex=e.outIfIndex;out[gid].nextHop=e.nextHop;}";
}

@end
