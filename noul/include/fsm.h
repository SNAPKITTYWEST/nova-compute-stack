// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT

#ifndef NOUL_FSM_H
#define NOUL_FSM_H

#include <stdint.h>
#include "noul_types.h"

typedef enum {
    FSM_STATE_START = 0,
    FSM_STATE_EXPECT_INDEX,
    FSM_STATE_EXPECT_CONFIDENCE,
    FSM_STATE_EXPECT_BITMASK,
    FSM_STATE_ACCEPT,
    FSM_STATE_REJECT
} fsm_state;

typedef struct {
    fsm_state  state;
    noul_mode  mode;
    uint32_t   num_classes;
} fsm_ctx;

void fsm_init(fsm_ctx *ctx, noul_mode mode, uint32_t num_classes);

int fsm_consume(fsm_ctx *ctx, const float *logits, noul_decision *out);

#endif /* NOUL_FSM_H */
