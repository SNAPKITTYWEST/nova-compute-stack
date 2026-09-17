// Copyright 2026 The Noul Authors.
// SPDX-License-Identifier: Apache-2.0 OR MIT

use std::os::raw::{c_void, c_int};

#[repr(C)]
pub struct Decision {
    pub class_index: u32,
    pub confidence:  f32,
    pub bitmask:     u32,
    pub valid:       u8,
    _pad:            [u8; 3],
}

extern "C" {
    fn noul_create(schema: *const u8, len: usize,
                   hidden_dim: u32, num_classes: u32) -> *mut c_void;
    fn noul_run(engine: *mut c_void, input: *const c_void,
                out: *mut Decision) -> c_int;
    fn noul_destroy(engine: *mut c_void);
    fn noul_backend_name() -> *const std::os::raw::c_char;
}

pub struct Engine { handle: *mut c_void }
unsafe impl Send for Engine {}

impl Engine {
    pub fn new(schema: &[u8], hidden_dim: u32, num_classes: u32) -> Result<Self, i32> {
        let h = unsafe {
            noul_create(schema.as_ptr(), schema.len(), hidden_dim, num_classes)
        };
        if h.is_null() { Err(-1) } else { Ok(Self { handle: h }) }
    }

    pub fn run(&self, input: *const c_void) -> Result<Decision, i32> {
        let mut d = Decision { class_index: 0, confidence: 0.0,
                               bitmask: 0, valid: 0, _pad: [0; 3] };
        let rc = unsafe { noul_run(self.handle, input, &mut d) };
        if rc == 0 { Ok(d) } else { Err(rc) }
    }

    pub fn backend() -> &'static str {
        unsafe {
            std::ffi::CStr::from_ptr(noul_backend_name())
                .to_str().unwrap_or("unknown")
        }
    }
}

impl Drop for Engine {
    fn drop(&mut self) { unsafe { noul_destroy(self.handle) } }
}
