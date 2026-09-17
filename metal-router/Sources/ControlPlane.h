// ControlPlane.h — Text-command control plane
//
// Supported commands:
//   add <prefix/len> via <nexthop> dev <ifIndex>
//   del <prefix/len>
//   show routes | stats | neighbors
#import <Foundation/Foundation.h>
#import "Router.h"

NS_ASSUME_NONNULL_BEGIN

@interface ControlPlane : NSObject
- (instancetype)initWithRouter:(Router *)router;
- (NSString *)executeCommand:(NSString *)cmd;
@end

NS_ASSUME_NONNULL_END
