#include <sys/time.h>

unsigned long long us_since_midnight() {
    struct timeval tv;
    if (gettimeofday(&tv, NULL) != 0)
        return 0;
    return (tv.tv_sec % 86400) * 1e9 + tv.tv_usec;
}

