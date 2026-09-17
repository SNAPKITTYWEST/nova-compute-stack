#ifndef CM_IR_H
#define CM_IR_H

#pragma once
#include <stdbool.h>
#include <stdint.h>
#include "ast.h"

typedef enum {
    CM_IR_TYPE_VOID,
    CM_IR_TYPE_BOOL,
    CM_IR_TYPE_I8, CM_IR_TYPE_I16, CM_IR_TYPE_I32, CM_IR_TYPE_I64,
    CM_IR_TYPE_U8, CM_IR_TYPE_U16, CM_IR_TYPE_U32, CM_IR_TYPE_U64,
    CM_IR_TYPE_F16, CM_IR_TYPE_F32, CM_IR_TYPE_F64,
    CM_IR_TYPE_VECTOR,
    CM_IR_TYPE_POINTER,
    CM_IR_TYPE_STRUCT,
    CM_IR_TYPE_COUNT
} cm_ir_type_kind_t;

typedef enum {
    CM_IR_AS_PRIVATE, CM_IR_AS_THREADGROUP,
    CM_IR_AS_DEVICE, CM_IR_AS_CONSTANT, CM_IR_AS_COUNT
} cm_ir_address_space_t;

typedef struct cm_ir_type {
    cm_ir_type_kind_t kind;
    uint32_t size;
    uint32_t alignment;
    union {
        struct { uint32_t element_count; struct cm_ir_type* element_type; } vector;
        struct { struct cm_ir_type* element_type; cm_ir_address_space_t address_space; } pointer;
        struct { char* name; struct cm_ir_field* fields; uint32_t field_count; } struct_type;
    };
} cm_ir_type_t;

typedef struct cm_ir_value cm_ir_value_t;

typedef enum {
    CM_IR_INSTR_RET, CM_IR_INSTR_BRANCH, CM_IR_INSTR_CONDBRANCH,
    CM_IR_INSTR_BINARY, CM_IR_INSTR_UNARY,
    CM_IR_INSTR_LOAD, CM_IR_INSTR_STORE, CM_IR_INSTR_ALLOCA,
    CM_IR_INSTR_GET_ELEMENT_PTR, CM_IR_INSTR_CALL, CM_IR_INSTR_INTRINSIC,
    CM_IR_INSTR_BARRIER, CM_IR_INSTR_ATOMIC, CM_IR_INSTR_PHI,
    CM_IR_INSTR_COUNT
} cm_ir_instr_kind_t;

typedef enum {
    CM_IR_BINOP_ADD, CM_IR_BINOP_SUB, CM_IR_BINOP_MUL, CM_IR_BINOP_DIV,
    CM_IR_BINOP_MOD, CM_IR_BINOP_AND, CM_IR_BINOP_OR, CM_IR_BINOP_XOR,
    CM_IR_BINOP_SHL, CM_IR_BINOP_SHR, CM_IR_BINOP_EQ, CM_IR_BINOP_NE,
    CM_IR_BINOP_LT, CM_IR_BINOP_GT, CM_IR_BINOP_LE, CM_IR_BINOP_GE
} cm_ir_binop_t;

typedef enum {
    CM_IR_UNOP_NEG, CM_IR_UNOP_NOT, CM_IR_UNOP_BITNOT
} cm_ir_unop_t;

typedef enum {
    CM_IR_ATOMIC_ADD, CM_IR_ATOMIC_SUB, CM_IR_ATOMIC_EXCH,
    CM_IR_ATOMIC_MIN, CM_IR_ATOMIC_MAX, CM_IR_ATOMIC_AND,
    CM_IR_ATOMIC_OR, CM_IR_ATOMIC_XOR
} cm_ir_atomic_op_t;

typedef enum {
    CM_IR_INTRINSIC_THREAD_IDX, CM_IR_INTRINSIC_BLOCK_IDX,
    CM_IR_INTRINSIC_BLOCK_DIM, CM_IR_INTRINSIC_GRID_DIM,
    CM_IR_INTRINSIC_SYNC_THREADS, CM_IR_INTRINSIC_SHFL,
    CM_IR_INTRINSIC_REDUCE, CM_IR_INTRINSIC_BALLOT,
    CM_IR_INTRINSIC_COUNT
} cm_ir_intrinsic_t;

typedef struct cm_ir_instr {
    cm_ir_instr_kind_t kind;
    cm_source_location_t loc;
    cm_ir_value_t* result;
    union {
        struct { cm_ir_value_t* value; } ret;
        struct { cm_ir_value_t* target; } branch;
        struct { cm_ir_value_t* cond; cm_ir_value_t* true_target; cm_ir_value_t* false_target; } condbranch;
        struct { cm_ir_binop_t op; cm_ir_value_t* lhs; cm_ir_value_t* rhs; } binary;
        struct { cm_ir_unop_t op; cm_ir_value_t* operand; } unary;
        struct { cm_ir_value_t* ptr; uint32_t alignment; } load;
        struct { cm_ir_value_t* value; cm_ir_value_t* ptr; uint32_t alignment; } store;
        struct { cm_ir_type_t* type; uint32_t count; } alloca;
        struct { cm_ir_value_t* ptr; cm_ir_value_t** indices; uint32_t index_count; } get_element_ptr;
        struct { cm_ir_value_t* callee; cm_ir_value_t** args; uint32_t arg_count; } call;
        struct { cm_ir_intrinsic_t intrinsic; cm_ir_value_t** args; uint32_t arg_count; } intrinsic;
        struct { uint32_t scope; } barrier;
        struct { cm_ir_atomic_op_t op; cm_ir_value_t* ptr; cm_ir_value_t* value; } atomic;
    };
    struct cm_ir_instr* next;
} cm_ir_instr_t;

typedef struct cm_ir_block {
    char* label;
    cm_ir_instr_t* first_instr;
    cm_ir_instr_t* last_instr;
    struct cm_ir_block** predecessors;
    uint32_t pred_count;
    struct cm_ir_block** successors;
    uint32_t succ_count;
    struct cm_ir_block* next;
} cm_ir_block_t;

struct cm_ir_param {
    char* name;
    cm_ir_type_t* type;
    uint32_t index;
    cm_ir_value_t value;
};

typedef struct cm_ir_function {
    char* name;
    cm_ir_type_t* return_type;
    struct cm_ir_param* params;
    uint32_t param_count;
    cm_ir_block_t* entry_block;
    cm_ir_block_t* exit_block;
    bool is_kernel;
    uint32_t grid[3];
    uint32_t block[3];
    uint32_t shared_mem;
    struct cm_ir_function* next;
} cm_ir_function_t;

typedef struct cm_ir_module {
    char* name;
    cm_ir_function_t* functions;
    cm_ir_type_t* types;
    uint32_t type_count;
    struct cm_ir_global* globals;
    uint32_t global_count;
} cm_ir_module_t;

typedef enum {
    CM_IR_VALUE_KIND_INSTRUCTION, CM_IR_VALUE_KIND_PARAMETER,
    CM_IR_VALUE_KIND_GLOBAL, CM_IR_VALUE_KIND_CONSTANT,
    CM_IR_VALUE_KIND_ARGUMENT, CM_IR_VALUE_KIND_COUNT
} cm_ir_value_kind_t;

struct cm_ir_value {
    cm_ir_value_kind_t kind;
    cm_ir_type_t* type;
    char* name;
    uint32_t id;
    union {
        cm_ir_instr_t* instruction;
        struct cm_ir_param* parameter;
        struct cm_ir_global* global;
        struct cm_ir_constant* constant;
        struct cm_ir_argument* argument;
    };
    struct cm_ir_value* next;
};

cm_ir_module_t* cm_ir_module_create(const char* name);
void cm_ir_module_destroy(cm_ir_module_t* module);
cm_ir_function_t* cm_ir_function_create(cm_ir_module_t* module, const char* name, cm_ir_type_t* return_type);
cm_ir_block_t* cm_ir_block_create(cm_ir_function_t* function, const char* label);
cm_ir_instr_t* cm_ir_instr_create(cm_ir_block_t* block, cm_ir_instr_kind_t kind, cm_source_location_t loc);
cm_ir_value_t* cm_ir_value_create_instruction(cm_ir_instr_t* instr, cm_ir_type_t* type);
cm_ir_value_t* cm_ir_value_create_parameter(uint32_t index, const char* name, cm_ir_type_t* type);
bool cm_ir_verify_module(cm_ir_module_t* module, cm_error_t** error);
bool cm_ir_verify_function(cm_ir_function_t* function, cm_error_t** error);

#endif // CM_IR_H
