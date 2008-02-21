#ifndef LIBEFAC_H
#define LIBEFAC_H

#include <inttypes.h>

#define efac_unused __attribute__((unused))
#if 0
#define EFAC_BARRIER(var) asm("mfence\n\t":::"memory")
#else
#define EFAC_BARRIER(var) asm("clflush %0\n\t"::"m"(var):"memory")
#endif

#if 1
#define EFAC_WRITE(var, val) (var) = (val)
#else
#define EFAC_WRITE(var, val) asm("movnti %1, %0\n\t" : "=m"(var) : "r"(val))
#endif

extern volatile uint8_t efac_regs[];
extern int efac_idx;
int efac_init(void);
void efac_save(int reg, uint32_t buf[512]);
void efac_restore(int reg, const uint32_t buf[512]);

static inline efac_unused void efac_clear(int reg) {
  volatile uint32_t *regb = (volatile uint32_t *)&efac_regs[reg * 4096];
  EFAC_WRITE(regb[512], 0x00070004);
  EFAC_BARRIER(regb[512]);
}

static inline efac_unused void efac_add(int reg, float val) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_WRITE(regb[efac_idx++], val);
  efac_idx &= 7;
  if (efac_idx)
    return;
  EFAC_BARRIER(regb[0]);
}

static inline efac_unused void efac_sub(int reg, float val) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_WRITE(regb[128 + efac_idx++], val);
  efac_idx &= 7;
  if (efac_idx)
    return;
  EFAC_BARRIER(regb[128]);
}

static inline efac_unused void efac_add4(int reg,
          float val1, float val2, float val3, float val4) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_WRITE(regb[16+0], val1);
  EFAC_WRITE(regb[16+1], val2);
  EFAC_WRITE(regb[16+2], val3);
  EFAC_WRITE(regb[16+3], val4);
  EFAC_BARRIER(regb[16]);
}

static inline efac_unused void efac_add8(int reg,
          float val1, float val2, float val3, float val4,
          float val5, float val6, float val7, float val8) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  regb[32+0] = val1; regb[32+1] = val2;
  regb[32+2] = val3; regb[32+3] = val4;
  regb[32+4] = val5; regb[32+5] = val6;
  regb[32+6] = val7; regb[32+7] = val8;
  EFAC_BARRIER(regb[32]);
}

static inline efac_unused void efac_sub4(int reg,
          float val1, float val2, float val3, float val4) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  regb[128+16+0] = val1;
  regb[128+16+1] = val2;
  regb[128+16+2] = val3;
  regb[128+16+3] = val4;
  EFAC_BARRIER(regb[128+16]);
}

static inline efac_unused float efac_read(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[0]);
  return *regb;
}

// NOTE: rounding may have a bias currently due to the internal
// twos-complement notation
static inline efac_unused float efac_read_round_zero(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[0]);
  return *regb;
}

static inline efac_unused float efac_read_round_inf(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[1]);
  return *regb;
}

static inline efac_unused float efac_read_round_ninf(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[2]);
  return *regb;
}

static inline efac_unused float efac_read_round_pinf(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[3]);
  return *regb;
}

static inline efac_unused float efac_read_round_nearest(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[4]);
  return *regb;
}

#endif /* LIBEFAC_H */
