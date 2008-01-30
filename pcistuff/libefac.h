#ifndef LIBEFAC_H
#define LIBEFAC_H

#include <inttypes.h>

#define efac_unused __attribute__((unused))

extern uint8_t efac_regs[];
extern int efac_idx;
int efac_init(void);
static inline efac_unused void efac_acc(int reg, float val) {
  volatile float *regb = &efac_regs[reg * 4096];
  regb[efac_idx++] = val;
  if (!(efac_idx & 8))
    return;
  asm("sfence\n\t":::"memory");
  efac_idx = 0;
}

#endif /* LIBEFAC_H */
