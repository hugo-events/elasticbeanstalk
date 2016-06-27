#ifndef XDIGEST_H
#define XDIGEST_H 1

#include "ruby.h"
#include "data.h"

typedef struct index {
    int fresh;
    int forward;
	long page;
    long element;
} Index;

typedef struct digest {
    VALUE rb_digest;
    Data *data;
    long compression;
    long total_weight;
    long centroid_count;
} Digest;

#endif /* XDIGEST */
