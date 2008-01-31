#include <inttypes.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include "libefac.h"

#define MAXLINE 48
char buffer[MAXLINE];

const char help_text[] =
  "Commands:\n"
  "  h\n"
  "  help\n"
  "    Print this help message\n"
  "  q\n"
  "  quit\n"
  "    Quit program\n"
  "  b\n"
  "    Unfinished benchmark code\n"
  "  sf\n"
  "  lf\n"
  "  mf\n"
  "    Store/load/memory fences\n"
  "  a <reg> <float>\n"
  "    Add float to register reg\n"
  "  r32 <addr>\n"
  "  r64 <addr>\n"
  "  rf <addr>\n"
  "  rd <addr>\n"
  "  w32 <addr> <int>\n"
  "  w64 <addr> <int>\n"
  "  wf <addr> <float>\n"
  "  wd <addr> <float>\n"
  "";

int process_command(volatile uint8_t *mapped) {
  volatile double *mapped_double = (double *)mapped;
  volatile float *mapped_float = (float *)mapped;
  volatile uint32_t *mapped_32 = (uint32_t *)mapped;
  volatile uint64_t *mapped_64 = (uint64_t *)mapped;
  uint64_t vali;
  double valf;
  int addr;
  char *par1;
  char *par2 = NULL;
  char *eol;
  fgets(buffer, sizeof(buffer), stdin);
  eol = strchr(buffer, '\n');
  if (eol) *eol = 0;
  par1 = strchr(buffer, ' ');
  if (par1) {
    char *end;
    *par1++ = 0;
    par2 = strchr(par1, ' ');
    if (par2) {
      char *endf;
      *par2++ = 0;
      vali = strtol(par2, &end, 0);
      valf = strtod(par2, &endf);
      if (*end && *endf) {
        printf("error parsing value\n");
        return 1;
      }
    }
    addr = strtol(par1, &end, 0);
    if (*end && end != par2) {
      printf("error parsing address\n");
      return 1;
    }
  }
  if (strcmp(buffer, "h") == 0 || strcmp(buffer, "help") == 0) {
    printf(help_text);
    return 1;
  }
  if (strcmp(buffer, "q") == 0 || strcmp(buffer, "quit") == 0)
    return 0;
  if (strcmp(buffer, "b") == 0) {
#define STEP 1
    int i = 100000000;
    do {
      efac_add4(0, 2.0, 2.0, 2.0, 2.0);
      efac_add4(0, 2.0, 2.0, 2.0, 2.0);
    } while (--i);
//    printf("%016"PRIx64"\n", mapped_64[2]);
  } else if (strcmp(buffer, "sf") == 0) {
      asm("sfence\n\t" ::: "memory");
  } else if (strcmp(buffer, "lf") == 0) {
      asm("lfence\n\t" ::: "memory");
  } else if (strcmp(buffer, "mf") == 0) {
      asm("mfence\n\t" ::: "memory");
  } else if (par1 && strcmp(buffer, "r64") == 0) {
    printf("%016"PRIx64"\n", mapped_64[addr]);
  } else if (par1 && strcmp(buffer, "r32") == 0) {
    printf("%08"PRIx32"\n", mapped_32[addr]);
  } else if (par1 && strcmp(buffer, "rf") == 0) {
    printf("%e\n", (double)mapped_float[addr]);
  } else if (par1 && strcmp(buffer, "rd") == 0) {
    printf("%e\n", mapped_double[addr]);
  } else if (par1 && strcmp(buffer, "r") == 0) {
    printf("%e\n", (double)efac_read(addr));
  } else if (par1 && strcmp(buffer, "c") == 0) {
    efac_clear(addr);
  } else if (par1 && par2 && strcmp(buffer, "w64") == 0) {
    mapped_64[addr] = vali;
  } else if (par1 && par2 && strcmp(buffer, "w32") == 0) {
    mapped_32[addr] = vali;
  } else if (par1 && par2 && strcmp(buffer, "wf") == 0) {
    union {
      float f;
      uint32_t i;
    } dbg;
    dbg.f = valf;
printf("%08x\n", dbg.i);
    mapped_float[addr] = valf;
  } else if (par1 && par2 && strcmp(buffer, "wd") == 0) {
    mapped_double[addr] = valf;
  } else if (par1 && par2 && strcmp(buffer, "a") == 0) {
    efac_add(addr, valf);
  } else if (par1 && par2 && strcmp(buffer, "s") == 0) {
    efac_sub(addr, valf);
  } else
    printf("Unknown or invalid command\n");
  return 1;
}

int main(int argc, char *argv[]) {
  if (!efac_init()) {
    printf("device init failed!\n");
    return 1;
  }
  while (1) {
    printf("\n>"); fflush(stdout);
    if (!process_command(efac_regs)) break;
  }
  return 0;
}
