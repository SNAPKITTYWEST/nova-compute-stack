// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT
//
// CPU backend implementation.

#include "noul.h"
#include "backend.h"
#include "fsm.h"
#include <time.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

static char engine_error[1024];

static uint32_t noul_hash_string(const char *str, size_t len) {
    uint32_t hash = 5381;
    for (size_t i = 0; i < len; i++) hash = ((hash << 5) + hash) + (uint32_t)str[i];
    return hash;
}

struct noul_engine {
    noul_mode    mode;
    uint32_t     hidden_dim;
    uint32_t     num_classes;
    uint64_t     request_counter;
    const char  *last_error;
    fsm_ctx      fsm;
};

noul_engine *noul_create(const uint8_t *schema_blob, size_t schema_len,
                          uint32_t hidden_dim, uint32_t num_classes) {
    noul_engine *e = (noul_engine *)calloc(1, sizeof(noul_engine));
    if (!e) return NULL;
    e->hidden_dim   = hidden_dim;
    e->num_classes  = num_classes;
    e->mode         = (num_classes == 1) ? NOUL_MODE_SCORE :
                      (num_classes == 2) ? NOUL_MODE_BOOLEAN : NOUL_MODE_CHOICE;
    fsm_init(&e->fsm, e->mode, num_classes);
    return e;
}

int noul_run(noul_engine *engine, const void *input, noul_decision *out) {
    if (!engine || !input || !out) return NOUL_ERR_INVALID;
    engine->request_counter++;

    // CPU path: hash the input bytes as a deterministic mock forward pass.
    const uint8_t *bytes = (const uint8_t *)input;
    uint32_t h = noul_hash_string((const char *)bytes, engine->hidden_dim * sizeof(float));

    float logits[64] = {0};
    for (uint32_t i = 0; i < engine->num_classes && i < 64; i++) {
        logits[i] = (float)((h + i * 1234567) % 10000) / 10000.0f;
    }

    fsm_init(&engine->fsm, engine->mode, engine->num_classes);
    return fsm_consume(&engine->fsm, logits, out);
}

int noul_run_async(noul_engine *engine, const void *input,
                   noul_callback cb, void *user) {
    noul_decision d = {0};
    int rc = noul_run(engine, input, &d);
    if (cb) cb(rc, &d, user);
    return rc;
}

void noul_destroy(noul_engine *engine) {
    free(engine);
}

const char *noul_backend_name(void) {
    return "cpu";
}
