#ifndef LIBSOFTEFAC_H
#define LIBSOFTEFAC_H

#include <inttypes.h>

int efac_init(void);
void efac_save(int reg, uint32_t buf[512]);
void efac_restore(int reg, const uint32_t buf[512]);
void efac_clear(int reg);
void efac_add(int reg, float val);
float efac_read(int reg);

#endif /* LIBSOFTEFAC_H */
