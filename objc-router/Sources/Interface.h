// Interface.h — Network interface descriptor (Objective-C)
#import <Foundation/Foundation.h>

@interface Interface : NSObject
@property (nonatomic, assign) NSInteger  index;
@property (nonatomic, copy)   NSString  *name;
@property (nonatomic, assign) uint32_t   ip;    // host order
@property (nonatomic, assign) uint32_t   mask;  // host order
@property (nonatomic, assign) BOOL       up;
@property (nonatomic, assign) uint64_t   rxPackets, txPackets;
@property (nonatomic, assign) uint64_t   rxBytes,   txBytes, drops;

- (instancetype)initWithIndex:(NSInteger)idx name:(NSString *)name
                           ip:(uint32_t)ip mask:(uint32_t)mask;
- (BOOL)isLocal:(uint32_t)addr;
- (NSString *)description;
@end
