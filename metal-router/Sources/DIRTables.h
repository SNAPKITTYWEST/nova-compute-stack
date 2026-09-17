// DIRTables.h — Incremental DIR-24-8 (IPv4) + 16-bit multi-bit (IPv6) tables for GPU upload
#import <Foundation/Foundation.h>
#import "RouteTable.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    uint32_t nextHop;
    int32_t  outIfIndex;
    uint16_t secondaryIndex; // 0xFFFF = terminal
    uint8_t  prefixLen;
    uint8_t  flags;          // bit0 = valid
} DIREntry;

@interface DIRTables : NSObject

@property (nonatomic, strong) NSMutableData *tbl24;             // IPv4 2^24 entries
@property (nonatomic, strong) NSMutableData *tbl8;              // flattened secondaries
@property (nonatomic, assign) NSUInteger     ipv4SecondaryCount;

@property (nonatomic, strong) NSMutableData *tbl16;             // IPv6 2^16 entries
@property (nonatomic, strong) NSMutableData *tbl16_sec;
@property (nonatomic, assign) NSUInteger     ipv6SecondaryCount;

- (instancetype)initWithRouteTable:(RouteTable *)table;
- (void)addIPv4Route:(RouteEntry)e;
- (void)removeIPv4Route:(uint32_t)prefix len:(uint8_t)len;
- (void)rebuildAllFromRouteTable:(RouteTable *)table;

@end

NS_ASSUME_NONNULL_END
