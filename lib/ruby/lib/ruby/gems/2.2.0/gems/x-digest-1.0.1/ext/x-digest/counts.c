#include "xdigest.h"
#include "counts.h"
#include <stdbool.h>

#define DEFAULT_PAGE_SIZE 32

extern VALUE rb_mXDigest;
VALUE rb_cCounts;

static VALUE
counts_initialize(int argc, VALUE* argv, VALUE self)
{
    Counts *counts;
    Data_Get_Struct(self, Counts, counts);

    VALUE rb_page_size;
    rb_scan_args(argc, argv, "01", &rb_page_size);

    if (NIL_P(rb_page_size))
        rb_page_size = rb_int2inum(DEFAULT_PAGE_SIZE);

    long page_size = rb_fix2int(rb_page_size);
    long *values = (long*)malloc(sizeof(long)*page_size);
    if (values == NULL) {
        rb_raise(rb_eNoMemError, "allocation of values failed");
    }

    counts->max_size = page_size;
    counts->size = 0;
    counts->values = values;

    return self;
}

static void
counts_free(void *ptr) {
    Counts *c;

    if (0 == ptr) {
        return;
    }

    c = (Counts*)ptr;
    xfree(c->values);
    xfree(ptr);
}

static VALUE
counts_allocate(VALUE klass)
{
    Counts *counts;
    VALUE res = Data_Make_Struct(klass, Counts, 0, counts_free, counts);
    return res;
}

VALUE
counts_aref(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_index;
    rb_scan_args(argc, argv, "01", &rb_index);

    switch (TYPE(rb_index)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "not valid value");
            break;
    }

    Counts *counts;
    Data_Get_Struct(self, Counts, counts);
    long index = rb_fix2int(rb_index);

    if (index < counts->size) {
        return rb_long2num_inline(counts->values[index]);
    }
    return Qnil;
}

VALUE
counts_aset(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_index, rb_value;
    rb_scan_args(argc, argv, "02", &rb_index, &rb_value);

    switch (TYPE(rb_index)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "index is not a fixnum");
            break;
    }
    long index = rb_fix2int(rb_index);

    switch (TYPE(rb_value)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "value is not a fixnum");
            break;
    }
    long value = rb_fix2int(rb_value);

    if (value < 0) {
        rb_raise(rb_eArgError, "negative value");
    }

    Counts *counts;
    Data_Get_Struct(self, Counts, counts);

    if (index < 0) {
        rb_raise(rb_eArgError, "negative index value");
    }
    else if (index >= counts->max_size) {
        rb_raise(rb_eArgError, "index value out of bounds");
    }
    else if (index == counts->size) {
        counts->values[index] = value;
        counts->size++;
    }
    else if (index < counts->size) {
        counts->values[index] = value;
    }
    else {
        rb_raise(rb_eArgError, "out of order insert");
    }
    return Qnil;
}

VALUE
counts_insert(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_index, rb_value;
    rb_scan_args(argc, argv, "02", &rb_index, &rb_value);

    switch (TYPE(rb_index)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "index is not a fixnum");
            break;
    }
    long index = rb_fix2int(rb_index);

    switch (TYPE(rb_value)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "value is not a fixnum");
            break;
    }
    long value = rb_fix2int(rb_value);

    Counts *counts;
    Data_Get_Struct(self, Counts, counts);

    if (value < 0) {
        rb_raise(rb_eArgError, "negative value");
    }

    if (index < 0) {
        rb_raise(rb_eArgError, "negative index value");
    }
    else if (index >= counts->max_size) {
        rb_raise(rb_eArgError, "index value out of bounds");
    }
    else if (index == counts->size) {
        counts->values[index] = value;
        counts->size++;
    }
    else if (index < counts->size) {
        for (long i = counts->size - 1; i >= index; i--) {
            counts->values[i+1] = counts->values[i];
        }
        counts->values[index] = value;
        counts->size++;
    }
    else {
        rb_raise(rb_eArgError, "out of order insert");
    }
    return Qnil;
}

VALUE
counts_delete_at_m(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_index;
    rb_scan_args(argc, argv, "01", &rb_index);

    switch (TYPE(rb_index)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "not valid value");
            break;
    }
    long index = rb_fix2int(rb_index);

    Counts *counts;
    Data_Get_Struct(self, Counts, counts);

    if (index < counts->size) {
        double current_value = counts->values[index];

        for (long i = index; i < counts->size - 1; i++) {
            counts->values[i] = counts->values[i+1];
        }
        counts->size--;

        return rb_long2num_inline(current_value);
    }
    rb_raise(rb_eArgError, "index out of range");
}

VALUE
counts_size(VALUE self)
{
    Counts *counts;
    Data_Get_Struct(self, Counts, counts);

    return rb_int2inum(counts->size);
}

void
Init_counts(void)
{
    rb_mXDigest = rb_define_module("XDigest");

    // Counts
    rb_cCounts = rb_define_class_under(rb_mXDigest, "Counts", rb_cObject);
    rb_define_alloc_func(rb_cCounts, counts_allocate);
    rb_define_method(rb_cCounts, "initialize", counts_initialize, -1);
    rb_define_method(rb_cCounts, "[]", counts_aref, -1);
    rb_define_method(rb_cCounts, "[]=", counts_aset, -1);
    rb_define_method(rb_cCounts, "insert", counts_insert, -1);
    rb_define_method(rb_cCounts, "delete_at", counts_delete_at_m, -1);
    rb_define_method(rb_cCounts, "size", counts_size, 0);
}
