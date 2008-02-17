#include <math.h>
#include <inttypes.h>
#include "libsoftefac.h"

#define REGCNT 8
#define REGSIZE 23

typedef struct {
  uint32_t buffer[REGSIZE];
  uint32_t allmask;
  uint32_t allvalue;
  uint32_t padding[32-REGSIZE-2];
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

static uint32_t read(register_t *preg, int pos) {
  uint32_t mask = 1 << pos;
  int32_t val = preg->allvalue << (31 - pos);
  return preg->allmask & mask ? val >> 31 : preg->buffer[pos];
}

static int do_add(register_t *preg, int pos, uint32_t v) {
  uint32_t oldval = read(preg, pos);
  uint32_t newval = oldval + v;
  uint32_t mask = 1 << pos;
  preg->buffer[pos] = newval;
  if (newval && newval != -1) preg->allmask &= ~mask;
  else {
    preg->allmask |= mask;
    if (newval) preg->allvalue |= mask;
    else preg->allvalue &= ~mask;
  }
  return newval < oldval;
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
  int exp = 0;
  int pos;
  uint32_t tmp;
  int carry;
  register_t *preg = &regs[reg];
  int64_t mant = frexpf(val, &exp) * (1 << 25);
  if (val - val) { // Inf/NaN
    preg->allmask &= ~(-1 << REGSIZE);
    return;
  }
  if (!mant) return;
  exp += 126;
  if (exp < 0) {
    mant >>= exp;
    pos = 0;
  } else {
    pos = exp >> 5;
    mant <<= exp & 31;
  }
  pos += REGSIZE/2 - 4;
  carry = do_add(preg, pos, mant);
  pos++;
  mant >>= 32;
  carry = do_add(preg, pos, mant + carry);
  if (!carry ^ (mant < 0))
    return;
  pos++;
  carry = mant < 0 ? -1 : 1;
  tmp = mant < 0 ? preg->allvalue | ~preg->allmask :
                   preg->allvalue &  preg->allmask;
  preg->allvalue = tmp + (carry << pos);
  tmp ^= preg->allvalue;
  pos = efac_log2(tmp);
  if (pos >= REGSIZE) {
    if (pos == REGSIZE)
      preg->allmask &= ~(-1 << REGSIZE);
    return;
  } else if (!pos)
    return;
  do_add(preg, pos, carry);
}

void efac_add4(int reg, float val1, float val2, float val3, float val4) {
  efac_add(reg, val1);
  efac_add(reg, val2);
  efac_add(reg, val3);
  efac_add(reg, val4);
}

void efac_sub(int reg, float val) {
  efac_add(reg, -val);
}

void efac_sub4(int reg, float val1, float val2, float val3, float val4) {
  efac_sub(reg, val1);
  efac_sub(reg, val2);
  efac_sub(reg, val3);
  efac_sub(reg, val4);
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
  value = read(&regs[reg], pos);
  value <<= 32;
  pos--;
  if (pos >= 0) value |= read(&regs[reg], pos);
  pos -= REGSIZE/2 - 4;
  if (sign) value = -value;
  res = ldexpf(value, (pos << 5) - 126 - 25);
  return sign ? -res : res;
}
