#import "DIRTables.h"

@implementation DIRTables {
    NSMutableDictionary<NSNumber *, NSNumber *> *_secMap4;
    NSMutableArray<NSMutableData *> *_secondaries4;
}

- (instancetype)initWithRouteTable:(RouteTable *)table {
    self = [super init];
    if (self) {
        _secMap4 = [NSMutableDictionary dictionary];
        _secondaries4 = [NSMutableArray array];
        const NSUInteger TBL24_SIZE = 1 << 24;
        _tbl24 = [NSMutableData dataWithLength:TBL24_SIZE * sizeof(DIREntry)];
        DIREntry *p = (DIREntry *)_tbl24.mutableBytes;
        for (NSUInteger i = 0; i < TBL24_SIZE; i++) { p[i].outIfIndex = -1; p[i].secondaryIndex = 0xFFFF; }
        [self rebuildAllFromRouteTable:table];
    }
    return self;
}

- (void)flattenSecondaries {
    NSMutableData *all = [NSMutableData data];
    for (NSData *s in _secondaries4) [all appendData:s];
    self.tbl8 = all;
    self.ipv4SecondaryCount = _secondaries4.count;
}

- (void)addIPv4Route:(RouteEntry)e {
    if (e.prefixLen <= 24) {
        uint32_t start = e.prefix >> 8, count = 1u << (24 - e.prefixLen);
        DIREntry *tbl = (DIREntry *)self.tbl24.mutableBytes;
        for (uint32_t i = 0; i < count; i++) {
            DIREntry *de = &tbl[start + i];
            if (e.prefixLen >= de->prefixLen || de->outIfIndex < 0) {
                de->nextHop = e.nextHop; de->outIfIndex = e.outIfIndex;
                de->prefixLen = e.prefixLen; de->secondaryIndex = 0xFFFF; de->flags |= 1;
            }
        }
    } else {
        uint32_t idx24 = e.prefix >> 8;
        uint16_t secIdx;
        if (_secMap4[@(idx24)]) {
            secIdx = [_secMap4[@(idx24)] unsignedShortValue];
        } else {
            secIdx = (uint16_t)_secondaries4.count;
            _secMap4[@(idx24)] = @(secIdx);
            NSMutableData *sec = [NSMutableData dataWithLength:256 * sizeof(DIREntry)];
            DIREntry *sp = (DIREntry *)sec.mutableBytes;
            for (int i = 0; i < 256; i++) { sp[i].outIfIndex = -1; sp[i].secondaryIndex = 0xFFFF; }
            [_secondaries4 addObject:sec];
            DIREntry *de24 = &((DIREntry *)self.tbl24.mutableBytes)[idx24];
            de24->secondaryIndex = secIdx;
        }
        DIREntry *secTbl = (DIREntry *)_secondaries4[secIdx].mutableBytes;
        uint32_t start = e.prefix & 0xFF, count = 1u << (32 - e.prefixLen);
        for (uint32_t i = 0; i < count; i++) {
            DIREntry *de = &secTbl[(start + i) & 0xFF];
            if (e.prefixLen >= de->prefixLen || de->outIfIndex < 0) {
                de->nextHop = e.nextHop; de->outIfIndex = e.outIfIndex;
                de->prefixLen = e.prefixLen; de->flags |= 1;
            }
        }
    }
    [self flattenSecondaries];
}

- (void)removeIPv4Route:(uint32_t)prefix len:(uint8_t)len {
    if (len <= 24) {
        uint32_t start = prefix >> 8, count = 1u << (24 - len);
        DIREntry *tbl = (DIREntry *)self.tbl24.mutableBytes;
        for (uint32_t i = 0; i < count; i++) {
            DIREntry *de = &tbl[start + i];
            if (de->prefixLen == len) { de->outIfIndex = -1; de->prefixLen = 0; de->flags = 0; }
        }
    }
}

- (void)rebuildAllFromRouteTable:(RouteTable *)table {
    DIREntry *p = (DIREntry *)self.tbl24.mutableBytes;
    for (NSUInteger i = 0; i < (1<<24); i++) { p[i].outIfIndex = -1; p[i].secondaryIndex = 0xFFFF; p[i].prefixLen = 0; p[i].flags = 0; }
    [_secMap4 removeAllObjects]; [_secondaries4 removeAllObjects];
    NSArray *entries = [[table allIPv4Entries] sortedArrayUsingComparator:^NSComparisonResult(NSValue *a, NSValue *b) {
        RouteEntry ea, eb; [a getValue:&ea]; [b getValue:&eb]; return eb.prefixLen - ea.prefixLen;
    }];
    for (NSValue *v in entries) { RouteEntry e; [v getValue:&e]; [self addIPv4Route:e]; }
}

@end
