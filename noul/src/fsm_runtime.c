// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT

#include "fsm.h"
#include <math.h>
#include <string.h>

void fsm_init(fsm_ctx *ctx, noul_mode mode, uint32_t num_classes) {
    ctx->state      = FSM_STATE_START;
    ctx->mode       = mode;
    ctx->num_classes = num_classes;
}

int fsm_consume(fsm_ctx *ctx, const float *logits, noul_decision *out) {
    if (!ctx || !logits || !out) return NOUL_ERR_INVALID;
    if (ctx->state == FSM_STATE_REJECT) return NOUL_ERR_FSM_REJECT;

    memset(out, 0, sizeof(*out));

    switch (ctx->mode) {
    case NOUL_MODE_BOOLEAN:
        if (ctx->num_classes != 2) return NOUL_ERR_FSM_REJECT;
        out->class_index = (logits[0] >= logits[1]) ? 0 : 1;
        out->confidence  = 1.0f;
        out->valid       = 1;
        ctx->state       = FSM_STATE_ACCEPT;
        return NOUL_OK;

    case NOUL_MODE_CHOICE: {
        uint32_t best     = 0;
        float    best_val = logits[0];
        for (uint32_t i = 1; i < ctx->num_classes; ++i) {
            if (logits[i] > best_val) { best_val = logits[i]; best = i; }
        }
        out->class_index = best;
        float sum = 0.0f;
        for (uint32_t i = 0; i < ctx->num_classes; ++i)
            sum += expf(logits[i] - best_val);
        out->confidence  = 1.0f / sum;
        out->valid       = 1;
        ctx->state       = FSM_STATE_ACCEPT;
        return NOUL_OK;
    }

    case NOUL_MODE_SCORE:
        if (ctx->num_classes != 1) return NOUL_ERR_FSM_REJECT;
        out->confidence  = 1.0f / (1.0f + expf(-logits[0]));
        out->valid       = 1;
        ctx->state       = FSM_STATE_ACCEPT;
        return NOUL_OK;

    case NOUL_MODE_MULTI: {
        uint32_t mask = 0;
        for (uint32_t i = 0; i < ctx->num_classes; ++i) {
            float p = 1.0f / (1.0f + expf(-logits[i]));
            if (p >= 0.5f) mask |= (1u << i);
        }
        out->bitmask = mask;
        out->valid   = 1;
        ctx->state   = FSM_STATE_ACCEPT;
        return NOUL_OK;
    }

    default:
        ctx->state = FSM_STATE_REJECT;
        return NOUL_ERR_FSM_REJECT;
    }
}
