// DIR24_8.h — Two-level DIR-24-8 LPM table builder (Objective-C)
//
// O(1) lookup for prefixes ≤ /24 (single tbl24 index)
// O(2) lookup for prefixes /25–/32 (tbl24 → tbl8 secondary)
// Designed for GPU upload: produces contiguous NSData suitable for MTLBuffer
#import <Foundation/Foundation.h>
#import "RouteTable.h"

typedef struct {
    uint32_t nextHop;
    int32_t  outIfIndex;
    uint16_t secondaryIndex; // 0xFFFF = terminal
    uint8_t  prefixLen;
    uint8_t  flags;          // bit0 = valid
} DIREntry;

@interface DIR24_8 : NSObject
@property (nonatomic, strong) NSData  *tbl24;
@property (nonatomic, strong) NSData  *tbl8;
@property (nonatomic, assign) NSUInteger secondaryCount;

- (instancetype)initWithRouteTable:(RouteTable *)table;
- (void)rebuildFromRouteTable:(RouteTable *)table;
- (void)addRoute:(RouteEntry)e;
@end
