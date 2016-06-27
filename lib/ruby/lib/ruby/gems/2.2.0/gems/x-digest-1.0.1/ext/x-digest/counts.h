#ifndef COUNTS_H
#define COUNTS_H 1

#include "ruby.h"

typedef struct counts {
    long size;
    long max_size;
    long *values;
} Counts;

extern VALUE rb_cCounts;

void Init_counts();

#endif /* COUNTS */
