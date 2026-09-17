#ifndef CM_CODEGEN_H
#define CM_CODEGEN_H

#pragma once
#include "ir.h"

typedef struct cm_msl_generator {
    cm_ir_module_t* module;
    char* output;
    size_t output_size;
    size_t output_capacity;
    uint32_t indent_level;
    uint32_t buffer_index;
    cm_error_t* error;
} cm_msl_generator_t;

cm_msl_generator_t* cm_msl_generator_create(cm_ir_module_t* module);
void cm_msl_generator_destroy(cm_msl_generator_t* gen);

bool cm_msl_generate(cm_msl_generator_t* gen);
const char* cm_msl_get_output(cm_msl_generator_t* gen);

void cm_msl_emit(cm_msl_generator_t* gen, const char* fmt, ...);
void cm_msl_emit_line(cm_msl_generator_t* gen, const char* fmt, ...);
void cm_msl_emit_indent(cm_msl_generator_t* gen);
void cm_msl_increase_indent(cm_msl_generator_t* gen);
void cm_msl_decrease_indent(cm_msl_generator_t* gen);

void cm_msl_gen_module(cm_msl_generator_t* gen, cm_ir_module_t* module);
void cm_msl_gen_function(cm_msl_generator_t* gen, cm_ir_function_t* function);
void cm_msl_gen_block(cm_msl_generator_t* gen, cm_ir_block_t* block);
void cm_msl_gen_instruction(cm_msl_generator_t* gen, cm_ir_instr_t* instr);

const char* cm_msl_type_to_string(cm_ir_type_t* type);
const char* cm_msl_address_space_to_string(cm_ir_address_space_t as);
const char* cm_msl_map_intrinsic(cm_ir_intrinsic_t intrinsic);
const char* cm_msl_map_atomic(cm_ir_atomic_op_t op);

#endif // CM_CODEGEN_H
