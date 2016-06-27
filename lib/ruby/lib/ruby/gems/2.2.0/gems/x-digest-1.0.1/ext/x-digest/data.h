#ifndef DATA_H
#define DATA_H 1

#include "ruby.h"
#include "page.h"

typedef struct data {
    long size;
    long max_size;
    Page **pages;
    VALUE *rb_pages;
} Data;

void Init_data();

#endif /* CENTROIDS */
