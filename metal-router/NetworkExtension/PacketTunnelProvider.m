#import "PacketTunnelProvider.h"

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary<NSString *,NSObject *> *)options
             completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NEPacketTunnelNetworkSettings *settings =
        [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"127.0.0.1"];

    NEIPv4Settings *v4 = [[NEIPv4Settings alloc] initWithAddresses:@[@"10.8.0.2"]
                                                       subnetMasks:@[@"255.255.255.0"]];
    v4.includedRoutes = @[[NEIPv4Route defaultRoute]];
    settings.IPv4Settings = v4;
    settings.MTU = @1400;

    [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
        if (error) { completionHandler(error); return; }
        [self readPackets];
        completionHandler(nil);
    }];
}

- (void)readPackets {
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> *packets,
                                                        NSArray<NSNumber *> *protocols) {
        // Convert NSData → Packet objects, call [router forwardBatch:…],
        // write results back with writePackets:withProtocols:
        [self readPackets]; // re-arm
    }];
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason
            completionHandler:(void (^)(void))completionHandler {
    completionHandler();
}

@end
