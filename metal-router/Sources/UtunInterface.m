#import "UtunInterface.h"
#import <sys/socket.h>
#import <sys/kern_control.h>
#import <sys/ioctl.h>
#import <net/if_utun.h>
#import <net/if.h>
#import <unistd.h>

@implementation UtunInterface

- (BOOL)openWithUnit:(int)unit {
    self.fd = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL);
    if (self.fd < 0) return NO;
    struct ctl_info info = {0};
    strlcpy(info.ctl_name, UTUN_CONTROL_NAME, sizeof(info.ctl_name));
    if (ioctl(self.fd, CTLIOCGINFO, &info) == -1) { close(self.fd); self.fd = -1; return NO; }
    struct sockaddr_ctl addr = {0};
    addr.sc_len = sizeof(addr); addr.sc_family = AF_SYSTEM;
    addr.ss_sysaddr = AF_SYS_CONTROL; addr.sc_id = info.ctl_id; addr.sc_unit = unit + 1;
    if (connect(self.fd, (struct sockaddr *)&addr, sizeof(addr)) == -1) { close(self.fd); self.fd = -1; return NO; }
    char ifname[IFNAMSIZ] = {0}; socklen_t len = sizeof(ifname);
    if (getsockopt(self.fd, SYSPROTO_CONTROL, UTUN_OPT_IFNAME, ifname, &len) == 0) self.name = @(ifname);
    return YES;
}

- (NSData *)readPacket {
    uint8_t buf[2048]; ssize_t n = read(self.fd, buf, sizeof(buf));
    if (n <= 4) return nil;
    return [NSData dataWithBytes:buf + 4 length:n - 4];
}

- (BOOL)writePacket:(NSData *)pkt isIPv6:(BOOL)isIPv6 {
    uint32_t af = htonl(isIPv6 ? AF_INET6 : AF_INET);
    struct iovec iov[2] = { { &af, 4 }, { (void *)pkt.bytes, pkt.length } };
    return writev(self.fd, iov, 2) > 0;
}

- (void)close { if (self.fd >= 0) { close(self.fd); self.fd = -1; } }

@end
