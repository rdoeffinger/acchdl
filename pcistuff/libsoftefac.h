#ifndef LIBSOFTEFAC_H
#define LIBSOFTEFAC_H

#include <inttypes.h>

int efac_init(void);
void efac_save(int reg, uint32_t buf[512]);
void efac_restore(int reg, const uint32_t buf[512]);
void efac_clear(int reg);
void efac_add(int reg, float val);
void efac_sub(int reg, float val);
void efac_add4(int reg, float val1, float val2, float val3, float val4);
void efac_sub4(int reg, float val1, float val2, float val3, float val4);
float efac_read(int reg);

#endif /* LIBSOFTEFAC_H */
