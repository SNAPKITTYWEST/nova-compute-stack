// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT

#ifndef NOUL_BACKEND_H
#define NOUL_BACKEND_H

#include <stddef.h>
#include <stdint.h>

#if defined(__CUDACC__) && defined(NOUL_USE_CUDA)
  #define NOUL_BACKEND_CUDA 1
#elif defined(__APPLE__) && defined(NOUL_USE_METAL)
  #define NOUL_BACKEND_METAL 1
#else
  #define NOUL_BACKEND_CPU 1
#endif

typedef struct noul_buffer noul_buffer;

typedef struct {
    noul_buffer *(*alloc)(size_t bytes);
    void (*free)(noul_buffer *buf);
    void *(*map)(noul_buffer *buf);
    int (*upload)(noul_buffer *buf, const void *src, size_t n);
    int (*download)(noul_buffer *buf, void *dst, size_t n);
    int (*decision_head)(noul_buffer *input,
                         noul_buffer *weights,
                         noul_buffer *bias,
                         noul_buffer *logits,
                         uint32_t hidden_dim,
                         uint32_t num_classes);
    const char *name;
} noul_backend_vtbl;

const noul_backend_vtbl *noul_get_backend(void);

#endif /* NOUL_BACKEND_H */
