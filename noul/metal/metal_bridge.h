// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT

#ifndef NOUL_METAL_BRIDGE_H
#define NOUL_METAL_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __APPLE__
#ifdef __cplusplus
extern "C" {
#endif

typedef struct noul_metal_ctx noul_metal_ctx;

noul_metal_ctx *noul_metal_create(void);
void noul_metal_destroy(noul_metal_ctx *ctx);

void *noul_metal_alloc(noul_metal_ctx *ctx, size_t bytes);
void noul_metal_free(noul_metal_ctx *ctx, void *ptr);

int noul_metal_decision_head(
    noul_metal_ctx *ctx,
    void *input, void *weights, void *bias, void *logits,
    uint32_t hidden_dim, uint32_t num_classes);

#ifdef __cplusplus
}
#endif
#endif /* __APPLE__ */
#endif /* NOUL_METAL_BRIDGE_H */
