// TrieNode.h — Binary trie node supporting IPv4 and IPv6
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TrieNode : NSObject
@property (nonatomic, strong, nullable) TrieNode *left;         // bit 0
@property (nonatomic, strong, nullable) TrieNode *right;        // bit 1
@property (nonatomic, assign) BOOL      isLeaf;
@property (nonatomic, assign) uint32_t  nextHop;                // host order (IPv4)
@property (nonatomic, strong, nullable) NSData *nextHopIPv6;    // 16 bytes
@property (nonatomic, assign) int32_t   outIfIndex;
@property (nonatomic, assign) uint8_t   prefixLen;
@end

NS_ASSUME_NONNULL_END
