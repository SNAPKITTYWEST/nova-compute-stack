// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT

#include <metal_stdlib>
using namespace metal;

/*
 * Decision head: logits[num_classes] = input[hidden_dim] @ W^T + b
 *
 * One threadgroup (32 threads) per output class. Each thread computes
 * a partial dot product, then a SIMD reduction produces the final logit.
 */
kernel void noul_decision_head(
    device const half   *input      [[buffer(0)]],
    device const half   *weights    [[buffer(1)]],
    device const float  *bias       [[buffer(2)]],
    device       float  *logits     [[buffer(3)]],
    constant uint32_t   &hidden_dim [[buffer(4)]],
    constant uint32_t   &num_classes[[buffer(5)]],
    uint gid [[threadgroup_position_in_grid]],
    uint tid [[thread_position_in_threadgroup]])
{
    if (gid >= num_classes) return;

    const uint lane = tid; // 0..31
    float partial = 0.0f;

    for (uint k = lane; k < hidden_dim; k += 32) {
        partial += float(input[k]) * float(weights[gid * hidden_dim + k]);
    }

    for (uint offset = 16; offset > 0; offset >>= 1) {
        partial += simd_shuffle_down(partial, offset);
    }

    if (lane == 0) {
        logits[gid] = partial + bias[gid];
    }
}
