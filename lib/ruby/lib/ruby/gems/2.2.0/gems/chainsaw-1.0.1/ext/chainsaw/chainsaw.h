#ifndef CHAINSAW_H
#define CHAINSAW_H 1

#include "ruby.h"
#include "ruby/io.h"

VALUE rb_mChainsaw;
VALUE rb_cChainsaw;
VALUE cut(VALUE self, VALUE str);

typedef struct transformations {
	long count;
	int *indexes;
} Transformations;

typedef struct chainsaw {
	Transformations *transformations;
    char delimeter;
    char *line;
    size_t line_size;
} Chainsaw;

#endif /* CHAINSAW_H */
