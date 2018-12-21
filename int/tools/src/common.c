#define _GNU_SOURCE
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define STOCK_SIZE 8

void error(const char *msg);

void error(const char *msg) {
    perror(msg);
    exit(0);
}


void pin_thread(int cpu);

void pin_thread(int cpu) {
    cpu_set_t mask;
    CPU_ZERO(&mask);
    CPU_SET(cpu, &mask);
    if (sched_setaffinity(0, sizeof(cpu_set_t), &mask) < 0)
        error("sched_setaffinity()");
}

unsigned long long ns_since_midnight(void);
unsigned long long ns_since_midnight(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_REALTIME, &ts) != 0)
        error("clock_gettime()");
    return ((ts.tv_sec % 86400) * 1e9) + ts.tv_nsec;
}

