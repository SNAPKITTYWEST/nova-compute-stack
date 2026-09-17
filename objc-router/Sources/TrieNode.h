// TrieNode.h — Binary trie node for LPM (Objective-C)
#import <Foundation/Foundation.h>

@interface TrieNode : NSObject
@property (nonatomic, strong) TrieNode *left;       // bit 0
@property (nonatomic, strong) TrieNode *right;      // bit 1
@property (nonatomic, assign) BOOL      isLeaf;
@property (nonatomic, assign) uint32_t  nextHop;
@property (nonatomic, assign) int32_t   outIfIndex;
@property (nonatomic, assign) uint8_t   prefixLen;
@end
