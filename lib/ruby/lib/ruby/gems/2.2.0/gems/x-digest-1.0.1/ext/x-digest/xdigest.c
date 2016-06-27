#include "xdigest.h"
#include "page.h"
#include "centroids.h"
#include "counts.h"
#include <stdbool.h>
#include <time.h>
#include <float.h>

VALUE rb_mXDigest;
VALUE rb_cDigest;

Index digest_build_index(int forward, long page, long element, Digest digest);
Index digest_next_index(Index *currentIndex, Digest digest);
Index digest_duplicate_index(Index sourceIndex);
Centroids digest_centroids_for_page(long index, Digest digest);

static VALUE
digest_initialize(int argc, VALUE* argv, VALUE self)
{
	VALUE rb_digest;
	rb_scan_args(argc, argv, "10", &rb_digest);

    switch (TYPE(rb_ivar_defined(rb_digest, rb_intern("@data")))) {
        case T_FALSE:
            rb_raise(rb_eTypeError, "invalid digest object");
            break;
    }
    VALUE rb_data = rb_iv_get(rb_digest, "@data");
    VALUE rb_iterator = rb_iv_get(rb_digest, "@iterator");

    ID to_enum_method = rb_intern("to_enum");
    if (! rb_respond_to(rb_iterator, to_enum_method))
        rb_raise(rb_eRuntimeError, "target must respond to 'to_enum'");

    ID to_reverse_enum_method = rb_intern("to_reverse_enum");
    if (! rb_respond_to(rb_iterator, to_reverse_enum_method))
        rb_raise(rb_eRuntimeError, "target must respond to 'to_reverse_enum'");

	Digest *digest;
	Data_Get_Struct(self, Digest, digest);

    Data *data;
    Data_Get_Struct(rb_data, Data, data);

    VALUE rb_compression = rb_iv_get(rb_digest, "@compression");
    long compression = rb_fix2int(rb_compression);

    digest->rb_digest = rb_digest;
    digest->data = data;
    digest->compression = compression;

	return self;
}

static void
digest_free(void *ptr) {
    if (0 == ptr) {
        return;
    }
    xfree(ptr);
}

static void
digest_mark(void *ptr) {
    if (0 == ptr) {
        return;
    }

    Digest *digest = (Digest*)ptr;
    rb_gc_mark(digest->rb_digest);
}

static VALUE
digest_allocate(VALUE klass)
{
	Digest *digest;
	VALUE res = Data_Make_Struct(klass, Digest, digest_mark, digest_free, digest);
	return res;
}

Index
digest_all_before(double value, Digest digest)
{
    long data_size = digest.data->size;

    if (data_size == 0) {
        return digest_build_index(true, -1, -1, digest);
    }

    for (long i = 1; i < data_size; i++) {
        Centroids centroids = digest_centroids_for_page(i, digest);

        if (centroids.active > 0 && centroids.values[0] > value) {
            Centroids centroids_previous = digest_centroids_for_page(i - 1, digest);

            for (long j = 0; j < centroids_previous.active; j++) {
                if (centroids_previous.values[j] > value) {
                    return digest_build_index(false, i - 1, j - 1, digest);
                }
            }
            return digest_build_index(false, i, -1, digest);
        }
    }

    Centroids centroids_last = digest_centroids_for_page(data_size - 1, digest);
    for (long i = 0; i < centroids_last.active; i++) {
        if (centroids_last.values[i] > value) {
            return digest_build_index(false, data_size - 1, i - 1, digest);
        }
    }

    return digest_build_index(false, data_size, -1, digest);
}

Index
digest_floor(double value, Digest digest)
{
    Index r;
    Index z;
    Index next_element;

    r = digest_all_before(value, digest);
    r = digest_next_index(&r, digest);
    if (r.page == -1 && r.element == -1) {
        return digest_build_index(true, -1, -1, digest);
    }
    next_element = r;
    z = r;

    while (true) {
        next_element = digest_next_index(&next_element, digest);
        if (next_element.page == -1 && next_element.element == -1)
            break;

        Centroids centroids = digest_centroids_for_page(z.page, digest);
        if (centroids.values[z.element] != value)
            break;

        r = z;
        z = next_element;
    }

    return r;
}

long digest_count(Index index, Digest digest) {
    Page *page = digest.data->pages[index.page];
    return page->counts->values[index.element];
}

long digest_total_count(long page_index, Digest digest) {
    Page *page = digest.data->pages[page_index];
    return page->total_count;
}

Index digest_increment(Index index, long delta, Digest digest) {
    long i = index.page;
    long j = index.element + delta;

    while (i < digest.data->size) {
        double active = (digest_centroids_for_page(i, digest)).active;
        if (j < active)
            break;

        j -= active;
        i++;
    }

    while (i > 0 && j < 0) {
        i--;
        double active = (digest_centroids_for_page(i, digest)).active;
        j += active;
    }
    return digest_build_index(true, i, j, digest);
}

long digest_head_sum(Index index, Digest digest) {
    long r = 0;

    for (int i = 0; i < index.page; i++) {
        r += digest_total_count(i, digest);
    }

    if (index.page < digest.data->size) {
        for (int i = 0; i < index.element; i++) {
            r += digest_count(digest_build_index(true, index.page, i, digest), digest);
        }
    }
    return r;
}

VALUE
digest_add(int argc, VALUE *argv, VALUE self)
{
	VALUE rb_value, rb_weight;
	rb_scan_args(argc, argv, "11", &rb_value, &rb_weight);

    double value;
    switch (TYPE(rb_value)) {
        case T_FLOAT:
            value = rb_float_value(rb_value);
            break;
        case T_DATA:
            value = NUM2DBL(rb_value);
            break;
        default:
            rb_raise(rb_eTypeError, "value is not a float");
            break;
    }

    long weight = 1;
    switch (TYPE(rb_weight)) {
        case T_FIXNUM:
            weight = rb_fix2int(rb_weight);
            break;
        case T_NIL:
            break;
        default:
            rb_raise(rb_eTypeError, "weight is not a fixnum");
            break;
    }

    Digest *digest;
    Data_Get_Struct(self, Digest, digest);

    Index start = digest_floor(value, *digest);
    if (start.page == -1 && start.element == -1) {
        VALUE rb_start = rb_funcall(digest->rb_digest, rb_intern("ceil"), 1, rb_float_new(value));
        if (TYPE(rb_start) != T_NIL) {
            long start_page = rb_fix2int(rb_iv_get(rb_start, "@page"));
            long start_element = rb_fix2int(rb_iv_get(rb_start, "@sub_page"));
            start = digest_build_index(true, start_page, start_element, *digest);
        }
    }

    if (start.page == -1 && start.element == -1) {
        rb_funcall(digest->rb_digest, rb_intern("add_raw"), 2, rb_float_new(value), rb_int2inum(weight));
    }
    else {
        double min_distance = DBL_MAX;
        long last_neighbor = 0;
        Index neighbors;
        Index neighbor;
        Index closest = digest_build_index(true, -1, -1, *digest);
        double n = 0;

        neighbors = digest_build_index(true, start.page, start.element, *digest);
        long i = 0;
        while (true) {
            neighbors = digest_next_index(&neighbors, *digest);
            neighbor = neighbors;
            if (neighbor.page == -1 && neighbor.element == -1) {
                break;
            }

            double z = fabsl(digest_centroids_for_page(neighbor.page, *digest).values[neighbor.element] - value);
            if (z == 0) {
                closest = neighbor;
                n = 1;
                break;
            }
            else if (z <= min_distance) {
                min_distance = z;
                last_neighbor = i;
            }
            else {
                break;
            }
            i++;
        }

        if (closest.page == -1 && closest.element == -1) {
            long sum = digest_head_sum(digest_build_index(true, start.page, start.element, *digest), *digest);

            i = 0;
            neighbors = digest_build_index(true, start.page, start.element, *digest);

            while (true) {
                neighbors = digest_next_index(&neighbors, *digest);
                if (neighbors.page == -1 && neighbors.element == -1) {
                    break;
                }

                neighbor = neighbors;
                if (i > last_neighbor) {
                    break;
                }

                long count = digest_count(neighbor, *digest);
                double z = fabsl(digest_centroids_for_page(neighbor.page, *digest).values[neighbor.element] - value);
                double q = (sum + count / 2.0) / digest->total_weight;
                double k = 4 * digest->total_weight * q * (1 - q) / digest->compression;

                if (z == min_distance && count + weight <= k) {
                    n += 1;
                    if (drand48() < 1 / n) {
                        closest = neighbor;
                    }
                }
                sum += count;
                i++;
            }
        }

        if (closest.page == -1 && closest.element == -1) {
            rb_funcall(digest->rb_digest, rb_intern("add_raw"), 2, rb_float_new(value), rb_int2inum(weight));
        }
        else {
            Page *page = digest->data->pages[closest.page];
            long current_weight = page->counts->values[closest.element] + weight;

            if (n == 1) {
                page->counts->values[closest.element] = current_weight;
                page->total_count = page->total_count + weight;

                Centroids closest_centroids = digest_centroids_for_page(closest.page, *digest);
                closest_centroids.values[closest.element] += (value - closest_centroids.values[closest.element]) / (current_weight);
                digest->total_weight += weight;
            }
            else {
                double center_mean = digest_centroids_for_page(closest.page, *digest).values[closest.element];
                double center = center_mean + (value - center_mean) / weight;

                Index prev_index = digest_increment(closest, -1, *digest);
                double prev_mean = digest_centroids_for_page(prev_index.page, *digest).values[prev_index.element];

                Index next_index = digest_increment(closest, 1, *digest);
                double next_mean = digest_centroids_for_page(next_index.page, *digest).values[next_index.element];

                if (prev_mean <= center && next_mean >= center) {
                    page->counts->values[closest.element] = current_weight;
                    page->total_count = page->total_count + weight;

                    Centroids closest_centroids = digest_centroids_for_page(closest.page, *digest);
                    closest_centroids.values[closest.element] = center;

                    digest->total_weight += weight;
                }
                else {
                    VALUE delete_index = rb_funcall(digest->rb_digest, rb_intern("memoized_index"), 2, rb_int2inum(closest.page), rb_int2inum(closest.element));
                    rb_funcall(digest->rb_digest, rb_intern("delete"), 1, delete_index);
                    rb_funcall(digest->rb_digest, rb_intern("add_raw"), 2, rb_float_new(center), rb_int2inum(current_weight));
                }
            }
        }
    }

    if (digest->centroid_count > 20 * digest->compression) {
        rb_funcall(digest->rb_digest, rb_intern("compress"), 0);
    }
    return Qnil;
}

VALUE
digest_get_total_weight(VALUE self)
{
    Digest *digest;
    Data_Get_Struct(self, Digest, digest);

    return rb_int2inum(digest->total_weight);
}

VALUE
digest_set_total_weight(int argc, VALUE *argv, VALUE self)
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

    Digest *digest;
    Data_Get_Struct(self, Digest, digest);

    digest->total_weight = value;

    return Qnil;
}

VALUE
digest_get_centroid_count(VALUE self)
{
    Digest *digest;
    Data_Get_Struct(self, Digest, digest);

    return rb_int2inum(digest->centroid_count);
}

VALUE
digest_set_centroid_count(int argc, VALUE *argv, VALUE self)
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

    Digest *digest;
    Data_Get_Struct(self, Digest, digest);

    digest->centroid_count = value;

    return Qnil;
}

Index
digest_duplicate_index(Index sourceIndex)
{
    Index duplicateIndex;
    duplicateIndex.fresh = sourceIndex.fresh;
    duplicateIndex.forward = sourceIndex.forward;
    duplicateIndex.page = sourceIndex.page;
    duplicateIndex.element = sourceIndex.element;
    return duplicateIndex;
}

Index
digest_build_index(int forward, long page, long element, Digest digest)
{
    Index nextIndex;
    nextIndex.fresh = true;
    nextIndex.forward = forward;
    nextIndex.page = page;
    nextIndex.element = element;

    long data_size = digest.data->size;

    if (nextIndex.forward == true) {
        if (nextIndex.page < 0 || nextIndex.page >= data_size) {
            nextIndex.page = -1;
            nextIndex.element = -1;
            return nextIndex;
        }
    }
    else {
        if (nextIndex.page >= 0 && nextIndex.element < 0) {
            nextIndex.page--;

            if (nextIndex.page >= 0 && nextIndex.page < data_size) {
                Centroids centroids = digest_centroids_for_page(nextIndex.page, digest);

                nextIndex.element = centroids.active - 1;
            }
        }
        if (nextIndex.page < 0 || nextIndex.page >= data_size) {
            nextIndex.page = -1;
            nextIndex.element = -1;
            return nextIndex;
        }
    }

    return nextIndex;
}

Index
digest_next_index(Index *currentIndex, Digest digest)
{
    if (currentIndex->fresh == true) {
        currentIndex->fresh = false;
        return *currentIndex;
    }

    long data_size = digest.data->size;

    if (currentIndex->forward == true) {
        Centroids centroids = digest_centroids_for_page(currentIndex->page, digest);

        if (currentIndex->element < centroids.active - 1) {
            Index nextIndex = digest_duplicate_index(*currentIndex);
            nextIndex.element++;
            return nextIndex;
        }
        else if (currentIndex->page < data_size - 1) {
            Index nextIndex = digest_duplicate_index(*currentIndex);
            nextIndex.page++;
            nextIndex.element = 0;
            return nextIndex;
        }
    }
    else {
        if (currentIndex->element > 0) {
            Index nextIndex = digest_duplicate_index(*currentIndex);
            nextIndex.element--;
            return nextIndex;
        }
        else if (currentIndex->page > 0) {
            Centroids centroids = digest_centroids_for_page(currentIndex->page - 1, digest);

            Index nextIndex = digest_duplicate_index(*currentIndex);
            nextIndex.page--;
            nextIndex.element = centroids.active - 1;
            return nextIndex;
        }
    }

    Index nextIndex = digest_duplicate_index(*currentIndex);
    nextIndex.page = -1;
    nextIndex.element = -1;
    return nextIndex;
}

Centroids
digest_centroids_for_page(long index, Digest digest)
{
    Page *page = digest.data->pages[index];
    return *page->centroids;
}

void
Init_xdigest(void)
{
    rb_mXDigest = rb_define_module("XDigest");

    // Digest
    rb_cDigest = rb_define_class_under(rb_mXDigest, "ArrayDigestExtended", rb_cObject);
    rb_define_alloc_func(rb_cDigest, digest_allocate);
    rb_define_method(rb_cDigest, "initialize", digest_initialize, -1);
    rb_define_method(rb_cDigest, "add", digest_add, -1);
    rb_define_method(rb_cDigest, "total_weight", digest_get_total_weight, 0);
    rb_define_method(rb_cDigest, "total_weight=", digest_set_total_weight, -1);
    rb_define_method(rb_cDigest, "centroid_count", digest_get_centroid_count, 0);
    rb_define_method(rb_cDigest, "centroid_count=", digest_set_centroid_count, -1);

    srand48(time(NULL));

    // Others
    Init_data();
    Init_centroids();
    Init_counts();
    Init_page();
}
