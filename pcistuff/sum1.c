#include <stdio.h>
#include "libefac.h"
int main(void) {
  int i;
  double v1 = 0;
  float v2 = 0;
  if (!efac_init()) {
    printf("init failed!\n");
    return 1;
  }
  efac_clear(0);
  for (i = 1; i < 100000000; i++) {
    v1 += 1.0 / i;
    v2 += 1.0 / i;
    efac_add(0, 1.0 / i);
//  printf("vals: %f %f %f\n", v1, v2, efac_read(0));
  }
  printf("vals: %e %e %e\n", v1, v2, efac_read(0));
  return 0;
}
