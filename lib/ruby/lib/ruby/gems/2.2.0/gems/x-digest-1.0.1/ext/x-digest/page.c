#include "xdigest.h"
#include "centroids.h"
#include "counts.h"
#include "page.h"
#include <stdbool.h>

extern VALUE rb_mXDigest;
VALUE rb_cPage;

static VALUE
page_initialize(int argc, VALUE* argv, VALUE self)
{
    Page *page;
    Data_Get_Struct(self, Page, page);

    VALUE rb_centroids;
    VALUE rb_counts;
    rb_scan_args(argc, argv, "20", &rb_centroids, &rb_counts);

    Centroids *centroids;
    Data_Get_Struct(rb_centroids, Centroids, centroids);

    Counts *counts;
    Data_Get_Struct(rb_counts, Counts, counts);

    page->centroids = centroids;
    page->counts = counts;
    page->total_count = 0;

    return self;
}

static void
page_free(void *ptr) {
    if (0 == ptr) {
        return;
    }
    xfree(ptr);
}

static VALUE
page_allocate(VALUE klass)
{
	Page *page;
	VALUE res = Data_Make_Struct(klass, Page, 0, page_free, page);
	return res;
}

VALUE
page_get_total_count(VALUE self)
{
    Page *page;
    Data_Get_Struct(self, Page, page);

    return rb_int2inum(page->total_count);
}

VALUE
page_set_total_count(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_value;
    rb_scan_args(argc, argv, "10", &rb_value);

    switch (TYPE(rb_value)) {
        case T_FIXNUM:
            break;
        default:
            rb_raise(rb_eTypeError, "value is not a fixnum");
            break;
    }
    long value = rb_fix2int(rb_value);

    Page *page;
    Data_Get_Struct(self, Page, page);
    page->total_count = value;

    return Qnil;
}

void
Init_page(void)
{
    rb_mXDigest = rb_define_module("XDigest");

    // PageExtented
    rb_cPage = rb_define_class_under(rb_mXDigest, "PageExtended", rb_cObject);
    rb_define_alloc_func(rb_cPage, page_allocate);
    rb_define_method(rb_cPage, "initialize", page_initialize, -1);
    rb_define_method(rb_cPage, "total_count", page_get_total_count, 0);
    rb_define_method(rb_cPage, "total_count=", page_set_total_count, -1);
}
