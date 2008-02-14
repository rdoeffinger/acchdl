#include <stdio.h>
#include "libefac.h"
#define PER_LOOP 8
int main(void) {
  int i;
  double v1 = 0;
  float v2 = 0;
  if (!efac_init()) {
    printf("init failed!\n");
    return 1;
  }
  efac_clear(0);
  for (i = 1; i < 100000000; i+=PER_LOOP) {
//    v1 += 1.0 / i;
//    v2 += 1.0 / i;
#if PER_LOOP == 1
    efac_add(0, 1.0 / (i + 0));
#elif PER_LOOP == 4
    efac_add4(0, 1.0 / (i + 0), 1.0 / (i + 1), 1.0 / (i + 2), 1.0 / (i + 3));
#elif PER_LOOP == 8
    efac_add8(0, 1.0 / (i + 0), 1.0 / (i + 1), 1.0 / (i + 2), 1.0 / (i + 3),
                 1.0 / (i + 4), 1.0 / (i + 5), 1.0 / (i + 6), 1.0 / (i + 7));
#else
#error unsuppoted PER_LOOP value
#endif
//  printf("vals: %f %f %f\n", v1, v2, efac_read(0));
  }
  printf("vals: %e %e %e\n", v1, v2, efac_read(0));
  return 0;
}
