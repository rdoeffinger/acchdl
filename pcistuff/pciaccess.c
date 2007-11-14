#include <inttypes.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <pci/pci.h>

#define VENDOR 7
#define DEVICE 7

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
  return 1;
  if (strcmp(buffer, "b") == 0) {
    int i;
    for (i = 0; i < 2; i++)
      mapped_float[0] = 1.0;
//    printf("%016"PRIx64"\n", mapped_64[2]);
  }
  if (par1 && strcmp(buffer, "r64") == 0) {
    printf("%016"PRIx64"\n", mapped_64[addr]);
  } else if (par1 && strcmp(buffer, "r32") == 0) {
    printf("%08"PRIx32"\n", mapped_32[addr]);
  } else if (par1 && strcmp(buffer, "rf") == 0) {
    printf("%f\n", (double)mapped_float[addr]);
  } else if (par1 && strcmp(buffer, "rd") == 0) {
    printf("%f\n", mapped_double[addr]);
  } else if (par1 && par2 && strcmp(buffer, "w64") == 0) {
    mapped_64[addr] = vali;
  } else if (par1 && par2 && strcmp(buffer, "w32") == 0) {
    mapped_32[addr] = vali;
  } else if (par1 && par2 && strcmp(buffer, "wf") == 0) {
    mapped_float[addr] = valf;
  } else if (par1 && par2 && strcmp(buffer, "wd") == 0) {
    mapped_double[addr] = valf;
  } else
    printf("Unknown or invalid command\n");
  return 1;
}

int find_device(off_t *map_base, size_t *map_size) {
  int found = 0;
  struct pci_access *pci_acc = pci_alloc();
  struct pci_dev *device;
  pci_init(pci_acc);
  pci_scan_bus(pci_acc);
  device = pci_acc->devices;
  while (device) {
    pci_fill_info(device, PCI_FILL_IDENT | PCI_FILL_BASES | PCI_FILL_SIZES);
    printf("device: %x %x %lx %lx\n", device->vendor_id, device->device_id,
             device->base_addr[0], device->size[0]);
    if (device->vendor_id == VENDOR && device->device_id == DEVICE) {
      *map_base = device->base_addr[0];
      *map_size = device->size[0];
      found = 1;
    }
    device = device->next;
  }
  pci_cleanup(pci_acc);
  return found;
}

void *map_physical(off_t base, size_t size) {
  void *mapped;
  int memfd = open("/dev/mem", O_RDWR);
  if (memfd == -1) {
    printf("could not open '/dev/mem'\n");
    return NULL;
  }
  mapped = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, base);
  close(memfd);
  return mapped;
}

int main(int argc, char *argv[]) {
  size_t map_size = 0;
  off_t map_base = 0;
  volatile uint8_t *mapped;
  if (!find_device(&map_base, &map_size)) {
    printf("device not found!\n");
    return 1;
  }
  if (!map_base || !map_size) {
    printf("device invalid!\n");
    return 1;
  }
  mapped = map_physical(map_base, map_size);
  if (!mapped) {
    printf("mmap of PCI device failed\n");
    return 1;
  }
  while (1) {
    printf("\n>"); fflush(stdout);
    if (!process_command(mapped)) break;
  }
  return 0;
}
