// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT

#ifndef NOUL_TYPES_H
#define NOUL_TYPES_H

#include <stdint.h>

typedef enum {
    NOUL_MODE_BOOLEAN   = 0,
    NOUL_MODE_CHOICE    = 1,
    NOUL_MODE_SCORE     = 2,
    NOUL_MODE_MULTI     = 3
} noul_mode;

typedef struct {
    uint32_t class_index;
    float    confidence;
    uint32_t bitmask;
    uint8_t  valid;
    uint8_t  _pad[3];
} noul_decision;

#define NOUL_OK            0
#define NOUL_ERR_INVALID  -1
#define NOUL_ERR_BACKEND  -2
#define NOUL_ERR_FSM_REJECT -3
#define NOUL_ERR_OOM      -4

#endif /* NOUL_TYPES_H */
