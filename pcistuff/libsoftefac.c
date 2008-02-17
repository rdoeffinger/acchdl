#include <math.h>
#include <inttypes.h>
#include "libsoftefac.h"

#define REGCNT 8
#define REGSIZE 23

typedef struct {
  uint32_t buffer[REGSIZE];
  uint32_t allmask;
  uint32_t allvalue;
} register_t;

static register_t regs[REGCNT];

int efac_init(void) {
  int i;
  for (i = 0; i < REGCNT; i++)
    efac_clear(i);
  return 1;
}

void efac_clear(int reg) {
  regs[reg].allmask = -1;
  regs[reg].allvalue = 0;
}

static int do_add(int reg, int pos, int sign, uint32_t v) {
  uint32_t oldval = regs[reg].buffer[pos];
  uint32_t newval = oldval + v;
  uint32_t mask = 1 << pos;
  regs[reg].buffer[pos] = newval;
  if (newval && newval != -1) regs[reg].allmask &= ~mask;
  else {
    regs[reg].allmask |= mask;
    if (newval) regs[reg].allvalue |= mask;
    else regs[reg].allvalue &= ~mask;
  }
  return sign ? -(newval > oldval) : newval < oldval;
}

static uint8_t log2_8bit[256] = {
  0, 0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3,
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
  5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
  5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
};

static int efac_log2(uint32_t v) {
  int log = 0;
  if (v >> 16) {
    v >>= 16;
    log += 16;
  }
  if (v >> 8) {
    v >>= 8;
    log += 8;
  }
  log += log2_8bit[v];
  return log;
}

void efac_add(int reg, float val) {
  int exp;
  int pos;
  int sign;
  int64_t mant;
  uint32_t tmp;
  int carry;
  if (!val) return;
  if (val - val) { // Inf/NaN
    regs[reg].allmask &= ~(1 << REGSIZE);
    return;
  }
  val = frexpf(val, &exp);
  sign = val < 0;
  mant = val * (1 << 25);
  exp += 126;
  if (exp <= 0) { // denormal
    mant >>= 1 - exp;
    pos = 0;
  } else {
    pos = exp >> 5;
    mant <<= exp & 31;
  }
  pos += REGSIZE/2 - 4;
  carry = do_add(reg, pos, sign, mant);
  pos++;
  mant >>= 32;
  carry = do_add(reg, pos, sign, mant + carry);
  if (!carry)
    return;
  pos++;
  tmp = sign ? regs[reg].allvalue | ~regs[reg].allmask :
               regs[reg].allvalue &  regs[reg].allmask;
  regs[reg].allvalue = tmp + (carry << pos);
  tmp ^= regs[reg].allvalue;
  pos = efac_log2(tmp);
  if (pos == REGSIZE) {
    regs[reg].allmask &= ~(1 << REGSIZE);
    return;
  } else if (!pos)
    return;
  do_add(reg, pos, sign, carry);
}

float efac_read(int reg) {
  int pos;
  float res;
  uint64_t value;
  uint32_t tmp = regs[reg].allvalue;
  int sign = tmp & (1 << REGSIZE);
  if (sign) tmp = ~tmp;
  tmp |= ~regs[reg].allmask;
  pos = efac_log2(tmp);
  if (pos >= REGSIZE)
    return 1.0/0.0;
  value = regs[reg].buffer[pos];
  value <<= 32;
  pos--;
  if (pos >= 0) value |= regs[reg].buffer[pos];
  pos -= REGSIZE/2 - 4;
  if (sign) value = -value;
  res = ldexpf(value, (pos << 5) - 126 - 25);
  return sign ? -res : res;
}
