#include "chainsaw.h"
#include <stdbool.h>

#define EOL '\n'
#define STRING 0
#define LONG 1
#define DOUBLE 2
#define LINE_BUF_SIZE 500
#define RB_ARY_INIT_SIZE 8

static long
chainsaw_naive_str_to_long(const char *p)
{
    long x = 0;
    bool neg = false;

    if (*p == '-') {
        neg = true;
        ++p;
    }
    while (*p >= '0' && *p <= '9') {
        x = (x*10) + (*p - '0');
        ++p;
    }
    if (neg) {
        x = -x;
    }
    return x;
}

double
chainsaw_naive_str_to_float(const char *p)
{
    int s;
    double acc;
    double k;

    if (!*p || *p == '?')
        return -1;
    s = 1;
    while (*p == ' ') p++;
    
    if (*p == '-') {
        s = -1; p++;
    }
    
    acc = 0;
    while (*p >= '0' && *p <= '9')
        acc = acc * 10 + *p++ - '0';
    
    if (*p == '.') {
        k = 0.1;
        p++;
        while (*p >= '0' && *p <= '9') {
            acc += (*p++ - '0') * k;
            k *= 0.1;
        }
    }
    return s * acc;
}

static VALUE
chainsaw_transform_value(const char* ptr, long len, int idx, Chainsaw *chainsaw)
{
    if (idx < chainsaw->transformations->count) {
        if (chainsaw->transformations->indexes[idx] == LONG) {
            long l = chainsaw_naive_str_to_long(ptr);
            return LONG2NUM(l);
        }
        else if (chainsaw->transformations->indexes[idx] == DOUBLE) {
            double d = chainsaw_naive_str_to_float(ptr);
            return DBL2NUM(d);
        }
    }

    // it has to be STRING
    return rb_str_new(ptr, len);
}

static VALUE
chainsaw_initialize(int argc, VALUE* argv, VALUE self)
{
    char *delimeter;
    char DELIM;
    size_t line_size;
    char *line;
    Chainsaw *chainsaw;
    VALUE rb_delimeter, rb_transformation_indexes;
    Transformations *transformations;

    Data_Get_Struct(self, Chainsaw, chainsaw);
    
    rb_scan_args(argc, argv, "02", &rb_delimeter, &rb_transformation_indexes);
    
    if (NIL_P(rb_transformation_indexes))
        rb_transformation_indexes = rb_ary_new();
    if (NIL_P(rb_delimeter))
        rb_delimeter = rb_str_buf_new2(",");

    delimeter = StringValueCStr(rb_delimeter);
    DELIM = delimeter[0];

    transformations = ALLOC(Transformations);    
    transformations->count = RARRAY_LEN(rb_transformation_indexes);
    transformations->indexes = (int*) malloc(transformations->count * sizeof(int));
    for (int i = 0; i < transformations->count; i++) {
        int index = NUM2INT(rb_ary_entry(rb_transformation_indexes, i));
        transformations->indexes[i] = index;
    }

    line_size = LINE_BUF_SIZE;
    line = malloc(line_size * sizeof(char));

    chainsaw->transformations = transformations;
    chainsaw->delimeter = DELIM;
    chainsaw->line_size = line_size;
    chainsaw->line = line;

    return self;
}

static void
chainsaw_free(void *ptr)
{
    Chainsaw *c;
    
    if (0 == ptr) {
        return;
    }
    c = (Chainsaw*)ptr;
    xfree(c->transformations->indexes);
    xfree(c->transformations);
    xfree(c->line);
    xfree(ptr);
}

VALUE
chainsaw_allocate(VALUE klass)
{
    Chainsaw *chainsaw;
    VALUE res = Data_Make_Struct(klass, Chainsaw, 0, chainsaw_free, chainsaw);
    return res;
}

VALUE
chainsaw_split(Chainsaw *chainsaw, char *line)
{
    char *token, *start, *nobackslash, *t2;
    int idx = 0;
    int count = 0;
    
    VALUE ary;
    
    if ((token = strchr(line, EOL))) {
        *token = '\0';
    }
    
    ary = rb_ary_new2(RB_ARY_INIT_SIZE); // magic number
    start = line;
    nobackslash = line;
    
    while (token = strchr(nobackslash, chainsaw->delimeter)) {
        count = 0;
        t2 = token - 1;

        while ((t2 >= line) && (*t2 == '\\')) {
            ++count;
            --t2;
        }
        if(count % 2 == 1) {
            nobackslash = token + 1;
            continue;
        }
        break;
    }
    idx = 0;
    
    while (token != NULL) {
        rb_ary_store(ary, idx, chainsaw_transform_value(start, token - start, idx, chainsaw));
        idx++;

        nobackslash = start = token + 1;

        while ((token = strchr(nobackslash, chainsaw->delimeter))) {
            count = 0;
            t2 = token - 1;
            while ((t2 >= line) && (*t2 == '\\')) {
                ++count;
                --t2;
            }
            if (count % 2 == 1) {
                nobackslash = token + 1;
                continue;
            }
            break;
        }
    }
    
    rb_ary_store(ary, idx, chainsaw_transform_value(start, strlen(start), idx, chainsaw));
    return ary;
}

/* https://github.com/evan/ccsv/blob/master/ext/ccsv.c */
VALUE
chainsaw_cut(VALUE self, VALUE input)
{
    Chainsaw *chainsaw;
    FILE *fd = NULL;
    bool lines_processed = false;
    ssize_t chars_read;
    ssize_t additional_chars_read;
    size_t subline_size;
    char *subline;

    switch (TYPE(input)) {
        case T_FILE:
            break;
        default:
            rb_raise(rb_eTypeError, "not valid value");
            break;
    }

    if(!rb_block_given_p()) {
        rb_raise(rb_eArgError, "block is required");
    }

    fd = rb_io_stdio_file(RFILE(input)->fptr);

    Data_Get_Struct(self, Chainsaw, chainsaw);

    while ((chars_read = getline(&chainsaw->line, &chainsaw->line_size, fd)) != -1) {
        lines_processed = true;

        // getline() can return partial lines, deal with them by reading until we find a line change
        while (chainsaw->line[chars_read - 1] != '\n') {
            subline_size = chainsaw->line_size - chars_read;
            subline = &chainsaw->line[chars_read];

            // there's always index chars_read since the buffer is NUL-terminated
            additional_chars_read = getline(&subline, &subline_size, fd);

            // buffer might have been expanded
            chainsaw->line_size += subline_size - (chainsaw->line_size - chars_read);

            // move the character do check for line change, unless we read nothing
            if (additional_chars_read != -1) {
                chars_read += additional_chars_read;
            }
        }

        rb_yield(chainsaw_split(chainsaw, chainsaw->line));
    }

    if (ferror(fd)) {
        rb_raise(rb_eIOError, "IO error");
    }
    clearerr(fd);

    if (lines_processed == true)
        return Qtrue;

    return Qfalse;
}

void
Init_chainsaw(void)
{
    rb_mChainsaw = rb_define_module("Chainsaw");
    rb_cChainsaw = rb_define_class_under(rb_mChainsaw, "Chainsaw", rb_cObject);

    rb_define_alloc_func(rb_cChainsaw, chainsaw_allocate);
    rb_define_method(rb_cChainsaw, "initialize", chainsaw_initialize, -1);
    rb_define_method(rb_cChainsaw, "cut", chainsaw_cut, 1);
}
