#include "xdigest.h"
#include "centroids.h"
#include <stdbool.h>

#define DEFAULT_PAGE_SIZE 32

extern VALUE rb_mXDigest;
VALUE rb_cCentroids;

static VALUE
centroids_initialize(int argc, VALUE* argv, VALUE self)
{
    Centroids *centroids;
    Data_Get_Struct(self, Centroids, centroids);

	VALUE rb_page_size;
	rb_scan_args(argc, argv, "01", &rb_page_size);

    if (NIL_P(rb_page_size))
        rb_page_size = rb_int2inum(DEFAULT_PAGE_SIZE);
    long page_size = rb_fix2int(rb_page_size);

    double *values = (double*)malloc(sizeof(double)*page_size);
    if (values == NULL) {
        rb_raise(rb_eNoMemError, "allocation of values failed");
    }

    centroids->count = page_size;
    centroids->active = 0;
    centroids->values = values;

	return self;
}

static void
centroids_free(void *ptr) {
    Centroids *c;

    if (0 == ptr) {
        return;
    }
    c = (Centroids*)ptr;
    xfree(c->values);
    xfree(ptr);
}

static VALUE
centroids_allocate(VALUE klass)
{
	Centroids *centroids;
	VALUE res = Data_Make_Struct(klass, Centroids, 0, centroids_free, centroids);
	return res;
}

VALUE
centroids_aref(int argc, VALUE *argv, VALUE self)
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

	Centroids *centroids;
	Data_Get_Struct(self, Centroids, centroids);

    if (index < centroids->active) {
        return rb_float_new(centroids->values[index]);
    }
    return Qnil;
}

VALUE
centroids_aset(int argc, VALUE *argv, VALUE self)
{
	VALUE rb_index, rb_float;
	rb_scan_args(argc, argv, "02", &rb_index, &rb_float);

    switch (TYPE(rb_index)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "index is not a fixnum");
            break;
    }
    long index = rb_fix2int(rb_index);

    switch (TYPE(rb_float)) {
        case T_FLOAT:
            break;
        default:
            rb_raise(rb_eTypeError, "value is not a float");
            break;
    }
    double value = rb_float_value(rb_float);

    Centroids *centroids;
	Data_Get_Struct(self, Centroids, centroids);

    if (index < 0) {
        rb_raise(rb_eArgError, "negative index value");
    }
    else if (index >= centroids->count) {
        rb_raise(rb_eArgError, "index value out of bounds");
    }
    else if (index == centroids->active) {
        centroids->values[index] = value;
        centroids->active++;
    }
    else if (index < centroids->active) {
        centroids->values[index] = value;
    }
    else {
        rb_raise(rb_eArgError, "out of order insert");
    }
    return Qnil;
}

VALUE
centroids_insert(int argc, VALUE *argv, VALUE self)
{
	VALUE rb_index, rb_float;
	rb_scan_args(argc, argv, "02", &rb_index, &rb_float);

    switch (TYPE(rb_index)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "index is not a fixnum");
            break;
    }
    long index = rb_fix2int(rb_index);

    switch (TYPE(rb_float)) {
        case T_FLOAT:
            break;
        default:
            rb_raise(rb_eTypeError, "value is not a float");
            break;
    }
    double value = rb_float_value(rb_float);

    Centroids *centroids;
    Data_Get_Struct(self, Centroids, centroids);

    if (index < 0) {
        rb_raise(rb_eArgError, "negative index value");
    }
    else if (index >= centroids->count) {
        rb_raise(rb_eArgError, "index value out of bounds");
    }
    else if (index == centroids->active) {
        centroids->values[index] = value;
        centroids->active++;
    }
    else if (index < centroids->active) {
        for (long i = centroids->active - 1; i >= index; i--) {
            centroids->values[i+1] = centroids->values[i];
        }
        centroids->values[index] = value;
        centroids->active++;
    }
    else {
        rb_raise(rb_eArgError, "out of order insert");
    }
    return Qnil;
}

VALUE
centroids_delete_at_m(int argc, VALUE *argv, VALUE self)
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

	Centroids *centroids;
	Data_Get_Struct(self, Centroids, centroids);

    if (index < centroids->active) {
        double current_value = centroids->values[index];

        for (long i = index; i < centroids->active - 1; i++) {
            centroids->values[i] = centroids->values[i+1];
        }
        centroids->active--;

        return rb_float_new(current_value);
    }
    rb_raise(rb_eArgError, "index out of range");
}

VALUE
centroids_size(VALUE self)
{
	Centroids *centroids;
	Data_Get_Struct(self, Centroids, centroids);

    return rb_int2inum(centroids->active);
}

void
Init_centroids(void)
{
    rb_mXDigest = rb_define_module("XDigest");

    // Centroids
    rb_cCentroids = rb_define_class_under(rb_mXDigest, "Centroids", rb_cObject);
    rb_define_alloc_func(rb_cCentroids, centroids_allocate);
    rb_define_method(rb_cCentroids, "initialize", centroids_initialize, -1);
    rb_define_method(rb_cCentroids, "[]", centroids_aref, -1);
    rb_define_method(rb_cCentroids, "[]=", centroids_aset, -1);
    rb_define_method(rb_cCentroids, "insert", centroids_insert, -1);
    rb_define_method(rb_cCentroids, "delete_at", centroids_delete_at_m, -1);
    rb_define_method(rb_cCentroids, "size", centroids_size, 0);
}
