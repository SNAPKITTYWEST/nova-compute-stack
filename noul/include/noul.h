// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT
//
// Zero-token decision engine — public C ABI.

#ifndef NOUL_H
#define NOUL_H

#include <stdint.h>
#include <stddef.h>
#include "noul_types.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct noul_engine noul_engine;

noul_engine *noul_create(const uint8_t *schema_blob, size_t schema_len,
                         uint32_t hidden_dim, uint32_t num_classes);

int noul_run(noul_engine *engine, const void *input,
             noul_decision *out_decision);

typedef void (*noul_callback)(int status, noul_decision *decision, void *user);

int noul_run_async(noul_engine *engine, const void *input,
                   noul_callback cb, void *user);

void noul_destroy(noul_engine *engine);

const char *noul_backend_name(void);

#ifdef __cplusplus
}
#endif
#endif /* NOUL_H */
