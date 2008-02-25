#include <stdio.h>
#ifdef SOFT
#include "libsoftefac.h"
#else
#include "libefac.h"
#endif
#define PER_LOOP 1

static uint32_t flt2int(float x) {
  union {
    float f;
    uint32_t i;
  } v;
  v.f = x;
  return v.i;
}

int main(void) {
  int i;
  double v1 = 0;
  float v2 = 0;
  float res[3];
  if (!efac_init()) {
    printf("init failed!\n");
    return 1;
  }
  efac_clear(0);
  for (i = 1; i < 100000000; i+=PER_LOOP) {
#if PER_LOOP == 1
    float f = 1.0 / i;
    v1 += f;
    v2 += f;
    efac_add(0, f);
#elif PER_LOOP == 4
    efac_add4(0, 1.0 / (i + 0), 1.0 / (i + 1), 1.0 / (i + 2), 1.0 / (i + 3));
#error unsupported PER_LOOP value
#endif
//  printf("vals: %f %f %f\n", v1, v2, efac_read(0));
  }
  res[0] = efac_read_round_nearest(0);
  res[1] = efac_read_round_inf(0);
  res[2] = efac_read_round_zero(0);
  printf("vals: %.18e %e %.18e %.18e %.18e\n", v1, v2, res[0], res[1], res[2]);
  printf("vals: %.18e %e %.18e\n", (float)v1, v2, efac_read(0));
  printf("vals: %x %x %x\n", flt2int(res[0]), flt2int(res[1]), flt2int(res[2]));
  return 0;
}
