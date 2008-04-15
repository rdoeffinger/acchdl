#include <stdio.h>
#include "libefac.h"

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
  for (i = 1; i < 100000000; i++) {
    float f = 1.0 / i;
    v1 += f;
    v2 += f;
    efac_add(0, f);
  }
  res[0] = efac_read_round_nearest(0);
  res[1] = efac_read_round_inf(0);
  res[2] = efac_read_round_zero(0);
  printf("vals: %.18e %e %.18e %.18e %.18e\n", v1, v2, res[0], res[1], res[2]);
  return 0;
}
