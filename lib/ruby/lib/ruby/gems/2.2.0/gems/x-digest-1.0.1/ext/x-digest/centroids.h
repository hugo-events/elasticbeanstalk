#ifndef CENTROIDS_H
#define CENTROIDS_H 1

#include "ruby.h"

typedef struct centroids {
	long count;
    long active;
	double *values;
} Centroids;

extern VALUE rb_cCentroids;

void Init_centroids();

#endif /* CENTROIDS */
