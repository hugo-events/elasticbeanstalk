#ifndef PAGE_EXT_H
#define PAGE_EXT_H 1

#include "ruby.h"
#include "centroids.h"
#include "counts.h"

typedef struct page {
    Centroids *centroids;
    Counts *counts;
    long total_count;
} Page;

void Init_page();

#endif /* CENTROIDS */
