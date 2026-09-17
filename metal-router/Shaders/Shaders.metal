// Shaders.metal — DIR-24-8 GPU LPM kernel
// O(1) for prefixes ≤/24, O(2) for /25–/32
#include <metal_stdlib>
using namespace metal;

struct DIREntry {
    uint   nextHop;
    int    outIfIndex;
    ushort secondaryIndex; // 0xFFFF = terminal
    uchar  prefixLen;
    uchar  flags;
};

struct PacketIn  { uint dstIP; };
struct PacketOut { int outIfIndex; uint nextHop; };

kernel void dir24_8_classify(
    device const DIREntry *tbl24 [[buffer(0)]],
    device const DIREntry *tbl8  [[buffer(1)]],
    device const PacketIn *pkts  [[buffer(2)]],
    device       PacketOut *out  [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    uint dst    = pkts[gid].dstIP;
    uint idx24  = dst >> 8;
    DIREntry e  = tbl24[idx24];

    if (e.secondaryIndex != 0xFFFF) {
        // /25–/32: check secondary table for longer match
        uint idx8  = dst & 0xFF;
        DIREntry s = tbl8[e.secondaryIndex * 256 + idx8];
        if (s.outIfIndex >= 0) e = s;
    }

    out[gid].outIfIndex = e.outIfIndex;
    out[gid].nextHop    = e.nextHop;
}
