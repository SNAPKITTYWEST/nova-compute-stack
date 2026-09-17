// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT
//
// CUDA WMMA decision head. FP16 input, FP32 accumulation.
// Targets Ampere+ (sm_80).

#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>
#include "noul_types.h"

using namespace nvcuda;

#define WMMA_M 16
#define WMMA_N 16
#define WMMA_K 16

__global__ void noul_decision_head_kernel(
    const __half * __restrict__ input,
    const __half * __restrict__ weights,
    const float  * __restrict__ bias,
    float        * __restrict__ logits,
    uint32_t hidden_dim,
    uint32_t num_classes)
{
    const int warp_id = (blockIdx.x * blockDim.x + threadIdx.x) / 32;
    const int lane    = threadIdx.x % 32;

    if (warp_id >= (int)num_classes) return;

    wmma::fragment<wmma::accumulator, WMMA_M, WMMA_N, WMMA_K, float> c_frag;
    wmma::fill_fragment(c_frag, 0.0f);

    for (uint32_t k = 0; k < hidden_dim; k += WMMA_K) {
        wmma::fragment<wmma::matrix_a, WMMA_M, WMMA_N, WMMA_K, __half, wmma::row_major> a_frag;
        wmma::fragment<wmma::matrix_b, WMMA_M, WMMA_N, WMMA_K, __half, wmma::row_major> b_frag;

        wmma::load_matrix_sync(a_frag, input + k, hidden_dim);
        wmma::load_matrix_sync(b_frag, weights + warp_id * hidden_dim + k, hidden_dim);
        wmma::mma_sync(c_frag, a_frag, b_frag, c_frag);
    }

    if (lane < WMMA_N) {
        logits[warp_id] = c_frag.x[0] + bias[warp_id];
    }
}

extern "C" int noul_cuda_decision_head(
    void *input, void *weights, void *bias, void *logits,
    uint32_t hidden_dim, uint32_t num_classes)
{
    dim3 block(32, 1, 1);
    dim3 grid((num_classes + 31) / 32);

    noul_decision_head_kernel<<<grid, block>>>(
        (const __half *)input,
        (const __half *)weights,
        (const float  *)bias,
        (float        *)logits,
        hidden_dim, num_classes);

    return cudaGetLastError() == cudaSuccess ? 0 : -1;
}
