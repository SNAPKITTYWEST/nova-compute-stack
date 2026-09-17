#import "ControlPlane.h"
#import <arpa/inet.h>

@interface ControlPlane ()
@property (nonatomic, weak) Router *router;
@end

@implementation ControlPlane

- (instancetype)initWithRouter:(Router *)router { self = [super init]; if (self) _router = router; return self; }

- (uint32_t)parseIP:(NSString *)s {
    struct in_addr a; if (inet_pton(AF_INET, s.UTF8String, &a) != 1) return 0;
    return ntohl(a.s_addr);
}

- (NSString *)executeCommand:(NSString *)cmd {
    NSArray *parts = [[cmd componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
                       filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    if (parts.count == 0) return @"empty command";
    NSString *op = parts[0];
    if ([op isEqualToString:@"show"] && parts.count > 1) {
        if ([parts[1] isEqualToString:@"routes"])    { [self.router dumpRoutes];             return @"ok"; }
        if ([parts[1] isEqualToString:@"stats"])     { [self.router dumpStats];              return @"ok"; }
        if ([parts[1] isEqualToString:@"neighbors"]) { [self.router.neighborCache dump];     return @"ok"; }
        return @"usage: show routes|stats|neighbors";
    }
    if ([op isEqualToString:@"add"] && parts.count >= 6) {
        NSArray *p = [parts[1] componentsSeparatedByString:@"/"];
        if (p.count != 2) return @"bad prefix";
        uint32_t prefix = [self parseIP:p[0]]; uint8_t len = (uint8_t)[p[1] intValue];
        uint32_t nh = [self parseIP:parts[3]]; NSInteger ifIdx = [parts[5] integerValue];
        [self.router addStaticRouteIPv4:prefix len:len nextHop:nh outIf:ifIdx];
        return @"route added";
    }
    if ([op isEqualToString:@"del"]) return @"delete: use rebuild for production";
    return @"unknown command";
}

@end
