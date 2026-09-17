// Shaders.metal — Metal GPU LPM kernels
// Two variants: linear scan (lpm_classify) and DIR-24-8 (dir24_8_classify)

#include <metal_stdlib>
using namespace metal;

struct RouteEntry { uint prefix,mask; uchar prefixLen,pad[3]; uint nextHop; int outIfIndex; uint metric; };
struct PacketIn  { uint dstIP, pad; };
struct PacketOut { int outIfIndex; uint nextHop; };
struct DIREntry  { uint nextHop; int outIfIndex; ushort secondaryIndex; uchar prefixLen,flags; };

// Linear scan — correct for any table size, O(n) per packet
kernel void lpm_classify(
    device const RouteEntry *routes [[buffer(0)]],
    device const PacketIn   *pkts   [[buffer(1)]],
    device       PacketOut  *out    [[buffer(2)]],
    constant uint           &nRoutes[[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    uint dst = pkts[gid].dstIP;
    int  bestIf = -1; uint bestNH = 0, bestLen = 0;
    for (uint i = 0; i < nRoutes; ++i) {
        RouteEntry r = routes[i];
        if ((dst & r.mask) == r.prefix && r.prefixLen > bestLen) {
            bestLen = r.prefixLen; bestIf = r.outIfIndex; bestNH = r.nextHop;
        }
    }
    out[gid].outIfIndex = bestIf; out[gid].nextHop = bestNH;
}

// DIR-24-8 — O(1) for prefixes ≤ /24, O(2) for /25–/32
kernel void dir24_8_classify(
    device const DIREntry *tbl24    [[buffer(0)]],
    device const DIREntry *tbl8     [[buffer(1)]],
    device const PacketIn *pkts     [[buffer(2)]],
    device       PacketOut *out     [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    uint dst = pkts[gid].dstIP;
    DIREntry e = tbl24[dst >> 8];
    if (e.secondaryIndex != 0xFFFF) {
        DIREntry s = tbl8[e.secondaryIndex * 256 + (dst & 0xFF)];
        if (s.outIfIndex >= 0) e = s;
    }
    out[gid].outIfIndex = e.outIfIndex; out[gid].nextHop = e.nextHop;
}
