# Copyright 2026 The Noul Authors.
# SPDX-License-Identifier: Apache-2.0 OR MIT

import ctypes
from dataclasses import dataclass

@dataclass
class Decision:
    class_index: int
    confidence: float
    bitmask: int
    valid: bool

class _DecisionC(ctypes.Structure):
    _fields_ = [
        ("class_index", ctypes.c_uint32),
        ("confidence",  ctypes.c_float),
        ("bitmask",     ctypes.c_uint32),
        ("valid",       ctypes.c_uint8),
        ("_pad",        ctypes.c_uint8 * 3),
    ]

class NoulEngine:
    def __init__(self, lib_path: str, schema: bytes,
                 hidden_dim: int, num_classes: int):
        self._lib = ctypes.CDLL(lib_path)
        self._lib.noul_create.restype  = ctypes.c_void_p
        self._lib.noul_create.argtypes = [
            ctypes.c_char_p, ctypes.c_size_t,
            ctypes.c_uint32, ctypes.c_uint32]
        self._lib.noul_run.argtypes  = [
            ctypes.c_void_p, ctypes.c_void_p,
            ctypes.POINTER(_DecisionC)]
        self._lib.noul_run.restype   = ctypes.c_int
        self._lib.noul_destroy.argtypes = [ctypes.c_void_p]
        self._engine = self._lib.noul_create(
            schema, len(schema), hidden_dim, num_classes)

    def run(self, input_ptr: int) -> Decision:
        out = _DecisionC()
        rc  = self._lib.noul_run(self._engine, input_ptr, ctypes.byref(out))
        if rc != 0:
            raise RuntimeError(f"noul_run failed: {rc}")
        return Decision(out.class_index, out.confidence,
                        out.bitmask, bool(out.valid))

    def __del__(self):
        if self._engine:
            self._lib.noul_destroy(self._engine)
