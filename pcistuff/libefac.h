#ifndef LIBEFAC_H
#define LIBEFAC_H

#include <inttypes.h>

//! used to suppress warnings about unused functions
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

/**
 * Hardware is mapped onto this, thus saving a pointer indirection.
 * Do not use this directly in an application!
 */
extern volatile uint8_t efac_regs[];
/**
 * Counter to allow for write-combining single writes.
 * Do not use this directly in an application!
 */
extern int efac_idx;

/**
 * Initialize the hardware and set every up.
 * \return 0 on error, 1 otherwise
 */
int efac_init(void);

/**
 * Save register state
 * \param reg register to save from
 * \param buf buffer to store state into
 */
void efac_save(int reg, uint32_t buf[512]);

/**
 * Restore register state
 * \param reg register to restore into
 * \param buf buffer to restore state from
 */
void efac_restore(int reg, const uint32_t buf[512]);

/**
 * Clear a register (set to zero, unset overflow, ...)
 * \param reg register to clear
 */
static inline efac_unused void efac_clear(int reg) {
  volatile uint32_t *regb = (volatile uint32_t *)&efac_regs[reg * 4096];
  EFAC_WRITE(regb[512], 0x00070004);
  EFAC_BARRIER(regb[512]);
}

/**
 * Add a float value to a register
 * \param reg register to add to
 * \param val value to add
 */
static inline efac_unused void efac_add(int reg, float val) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_WRITE(regb[efac_idx++], val);
  efac_idx &= 7;
  if (efac_idx)
    return;
  EFAC_BARRIER(regb[0]);
}

/**
 * Subtract a float value from a register
 * \param reg register to subtract from
 * \param val value to subtract
 */
static inline efac_unused void efac_sub(int reg, float val) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_WRITE(regb[128 + efac_idx++], val);
  efac_idx &= 7;
  if (efac_idx)
    return;
  EFAC_BARRIER(regb[128]);
}

/**
 * Add 4 float values to a register, should be faster than efac_add
 * \param reg register to add to
 * \param val1 1st value to add
 * \param val2 2nd value to add
 * \param val3 3rd value to add
 * \param val4 4th value to add
 */
static inline efac_unused void efac_add4(int reg,
          float val1, float val2, float val3, float val4) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_WRITE(regb[16+0], val1);
  EFAC_WRITE(regb[16+1], val2);
  EFAC_WRITE(regb[16+2], val3);
  EFAC_WRITE(regb[16+3], val4);
  EFAC_BARRIER(regb[16]);
}

/**
 * Subtract 4 float values from a register, should be faster than efac_sub
 * \param reg register to subtract from
 * \param val1 1st value to subtract
 * \param val2 2nd value to subtract
 * \param val3 3rd value to subtract
 * \param val4 4th value to subtract
 */
static inline efac_unused void efac_sub4(int reg,
          float val1, float val2, float val3, float val4) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  regb[128+16+0] = val1;
  regb[128+16+1] = val2;
  regb[128+16+2] = val3;
  regb[128+16+3] = val4;
  EFAC_BARRIER(regb[128+16]);
}

/**
 * Read the value of a register as float, rounding is unspecified
 * \param reg register to read
 * \return register value as float, no rounding specified
 */
static inline efac_unused float efac_read(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[0]);
  return regb[0];
}

// NOTE: rounding may have a bias currently due to the internal
// twos-complement notation
/**
 * Read the value of a register as float, rounding towards zero
 * \param reg register to read
 * \return register value as float, rounded towards 0
 */
static inline efac_unused float efac_read_round_zero(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[0]);
  return regb[0];
}

/**
 * Read the value of a register as float, rounding away from 0
 * \param reg register to read
 * \return register value as float, rounded away from 0
 */
static inline efac_unused float efac_read_round_inf(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[1]);
  return regb[1];
}

/**
 * Read the value of a register as float, rounding towards -infinity
 * \param reg register to read
 * \return register value as float, rounded towards -infinity
 */
static inline efac_unused float efac_read_round_ninf(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[2]);
  return regb[2];
}

/**
 * Read the value of a register as float, rounding towards +infinity
 * \param reg register to read
 * \return register value as float, rounded towards +infinity
 */
static inline efac_unused float efac_read_round_pinf(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[3]);
  return regb[3];
}

/**
 * Read the value of a register as float, rounding to nearest 
 * \param reg register to read
 * \return register value as float, rounded to the nearest value
 */
static inline efac_unused float efac_read_round_nearest(int reg) {
  volatile float *regb = (volatile float *)&efac_regs[reg * 4096];
  EFAC_BARRIER(regb[4]);
  return regb[4];
}

#endif /* LIBEFAC_H */
