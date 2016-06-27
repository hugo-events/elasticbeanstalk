#include "xdigest.h"
#include "data.h"
#include "page.h"
#include <stdbool.h>

extern VALUE rb_mXDigest;
VALUE rb_cData;

static VALUE
data_initialize(int argc, VALUE* argv, VALUE self)
{
    Data *data;
    Data_Get_Struct(self, Data, data);

    VALUE rb_max_size;
    rb_scan_args(argc, argv, "10", &rb_max_size);

    long max_size = rb_fix2int(rb_max_size);

    Page **pages = malloc(sizeof(Page*)*max_size);
    if (pages == NULL) {
        rb_raise(rb_eNoMemError, "allocation of pages failed");
    }

    VALUE *rb_pages = (VALUE*)malloc(sizeof(VALUE)*max_size);
    if (rb_pages == NULL) {
        rb_raise(rb_eNoMemError, "allocation of rb_pages failed");
    }

    data->size = 0;
    data->max_size = max_size;
    data->pages = pages;
    data->rb_pages = rb_pages;

    return self;
}

static void
data_free(void *ptr) {
    Data *d;

    if (0 == ptr) {
        return;
    }
    d = (Data*)ptr;
    xfree(d->pages);
    xfree(d->rb_pages);
    xfree(ptr);
}

static void
data_mark(void *ptr) {
    if (0 == ptr) {
        return;
    }

    Data *data = (Data*)ptr;
    for (int i = 0; i < data->size; i++) {
        rb_gc_mark(data->rb_pages[i]);
    }
}

static VALUE
data_allocate(VALUE klass)
{
    Data *data;
    VALUE res = Data_Make_Struct(klass, Data, data_mark, data_free, data);
    return res;
}

VALUE
data_aref(int argc, VALUE *argv, VALUE self)
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

    Data *data;
    Data_Get_Struct(self, Data, data);

    if (index < data->size) {
        return data->rb_pages[index];
    }
    return Qnil;
}

VALUE
data_aset(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_index, rb_page;
    rb_scan_args(argc, argv, "02", &rb_index, &rb_page);

    switch (TYPE(rb_index)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "index is not a fixnum");
            break;
    }
    long index = rb_fix2int(rb_index);

    Data *data;
    Data_Get_Struct(self, Data, data);

    Page *page;
    Data_Get_Struct(rb_page, Page, page);

    if (index < 0) {
        rb_raise(rb_eArgError, "negative index value");
    }
    else if (index >= data->max_size) {
        rb_raise(rb_eArgError, "index value out of bounds");
    }
    else if (index == data->size) {
        data->rb_pages[index] = rb_page;
        data->pages[index] = page;
        data->size++;
    }
    else if (index < data->size) {
        data->rb_pages[index] = rb_page;
        data->pages[index] = page;
    }
    else {
        rb_raise(rb_eArgError, "out of order insert");
    }
    return Qnil;
}

VALUE
data_insert(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_index, rb_page;
    rb_scan_args(argc, argv, "02", &rb_index, &rb_page);

    switch (TYPE(rb_index)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "index is not a fixnum");
            break;
    }
    long index = rb_fix2int(rb_index);

    Data *data;
    Data_Get_Struct(self, Data, data);

    Page *page;
    Data_Get_Struct(rb_page, Page, page);

    if (index < 0) {
        rb_raise(rb_eArgError, "negative index value");
    }
    else if (index >= data->max_size) {
        rb_raise(rb_eArgError, "index value out of bounds");
    }
    else if (index == data->size) {
        data->rb_pages[index] = rb_page;
        data->pages[index] = page;
        data->size++;
    }
    else if (index < data->size) {
        for (long i = data->size - 1; i >= index; i--) {
            data->rb_pages[i+1] = data->rb_pages[i];
            data->pages[i+1] = data->pages[i];
        }
        data->rb_pages[index] = rb_page;
        data->pages[index] = page;
        data->size++;
    }
    else {
        rb_raise(rb_eArgError, "out of order insert");
    }
    return Qnil;
}

VALUE
data_push(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_page;
    rb_scan_args(argc, argv, "01", &rb_page);

    Data *data;
    Data_Get_Struct(self, Data, data);

    Page *page;
    Data_Get_Struct(rb_page, Page, page);

    if (data->size == data->max_size) {
        rb_raise(rb_eArgError, "array is full");
    }

    data->rb_pages[data->size] = rb_page;
    data->pages[data->size] = page;
    data->size++;

    return Qnil;
}

VALUE
data_last(VALUE self)
{
    Data *data;
    Data_Get_Struct(self, Data, data);

    if (data->size > 0) {
        return data->rb_pages[data->size-1];
    }
    return Qnil;
}

VALUE
data_delete_at_m(int argc, VALUE *argv, VALUE self)
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

    Data *data;
    Data_Get_Struct(self, Data, data);

    if (index < data->size) {
        VALUE current_value = data->rb_pages[index];

        for (long i = index; i < data->size - 1; i++) {
            data->rb_pages[i] = data->rb_pages[i+1];
        }
        data->size--;

        return current_value;
    }
    rb_raise(rb_eArgError, "index out of range");
}

VALUE
data_size(VALUE self)
{
    Data *data;
    Data_Get_Struct(self, Data, data);

    return rb_int2inum(data->size);
}

VALUE
data_clear(VALUE self)
{
    Data *data;
    Data_Get_Struct(self, Data, data);

    data->size = 0;

    return Qnil;
}

void
Init_data(void)
{
    rb_mXDigest = rb_define_module("XDigest");

    // Data
    rb_cData = rb_define_class_under(rb_mXDigest, "Data", rb_cObject);
    rb_define_alloc_func(rb_cData, data_allocate);
    rb_define_method(rb_cData, "initialize", data_initialize, -1);
    rb_define_method(rb_cData, "at", data_aref, -1);
    rb_define_method(rb_cData, "[]", data_aref, -1);
    rb_define_method(rb_cData, "[]=", data_aset, -1);
    rb_define_method(rb_cData, "insert", data_insert, -1);
    rb_define_method(rb_cData, "<<", data_push, -1);
    rb_define_method(rb_cData, "delete_at", data_delete_at_m, -1);
    rb_define_method(rb_cData, "last", data_last, 0);
    rb_define_method(rb_cData, "size", data_size, 0);
    rb_define_method(rb_cData, "clear", data_clear, 0);
}
