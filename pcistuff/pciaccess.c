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

int main(int argc, char *argv[]) {
  struct pci_access *pci_acc = pci_alloc();
  struct pci_dev *device;
  size_t map_size = 0;
  off_t map_base = 0;
  uint64_t tmp;
  int memfd;
  volatile double *mapped_double;
  volatile float *mapped_float;
  volatile uint64_t *mapped;
  volatile uint32_t *mapped_dword;
  volatile uint8_t *mapped_byte;
  int i;
  pci_init(pci_acc);
  pci_scan_bus(pci_acc);
  device = pci_acc->devices;
  while (device) {
    pci_fill_info(device, PCI_FILL_IDENT | PCI_FILL_BASES | PCI_FILL_SIZES);
    printf("device: %x %x %lx %lx\n", device->vendor_id, device->device_id,
             device->base_addr[0], device->size[0]);
    if (device->vendor_id == VENDOR && device->device_id == DEVICE) {
      map_base = device->base_addr[0];
      map_size = device->size[0];
    }
    device = device->next;
  }
  pci_cleanup(pci_acc);
  if (!map_base || !map_size) {
    printf("device not found/invalid!\n");
    return 1;
  }
  memfd = open("/dev/mem", O_RDWR);
  if (memfd == -1) {
    printf("could not open '/dev/mem'\n");
    return 1;
  }
  mapped = mmap(NULL, map_size, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, map_base);
  mapped_double = (double *)mapped;
  mapped_float = (float *)mapped;
  mapped_dword = (uint32_t *)mapped;
  mapped_byte = (uint8_t *)mapped;
  while (1) {
    uint64_t vali;
    double valf;
    int addr;
    char *par1;
    char *par2 = NULL;
    char *eol;
    printf("\n>"); fflush(stdout);
    fgets(buffer, sizeof(buffer), stdin);
    eol = strchr(buffer, '\n');
    if (eol) *eol = 0;
    par1 = strchr(buffer, ' ');
    if (par1) {
      *par1++ = 0;
      par2 = strchr(par1, ' ');
      if (par2) {
        *par2++ = 0;
        vali = strtol(par2, NULL, 0);
        valf = strtod(par2, NULL);
      }
      addr = strtol(par1, NULL, 0);
    }
    if (strcmp(buffer, "q") == 0) break;
    if (par1 && strcmp(buffer, "r64") == 0) {
      printf("%016"PRIx64"\n", mapped[addr]);
    } else if (par1 && strcmp(buffer, "r32") == 0) {
      printf("%08"PRIx32"\n", mapped_dword[addr]);
    } else if (par1 && strcmp(buffer, "rf") == 0) {
      printf("%f\n", (double)mapped_float[addr]);
    } else if (par1 && strcmp(buffer, "rd") == 0) {
      printf("%f\n", mapped_double[addr]);
    } else if (par1 && par2 && strcmp(buffer, "w64") == 0) {
      mapped[addr] = vali;
    } else if (par1 && par2 && strcmp(buffer, "w32") == 0) {
      mapped_dword[addr] = vali;
    } else if (par1 && par2 && strcmp(buffer, "wf") == 0) {
      mapped_float[addr] = valf;
    } else if (par1 && par2 && strcmp(buffer, "wd") == 0) {
      mapped_double[addr] = valf;
    }
  }
#if 0
  printf("mapped\n"); fflush(stdout);
  usleep(1000 * 1000);
  printf("starting write\n"); fflush(stdout);
  usleep(1000 * 1000);
  mapped[1000] = 123;
  printf("wrote\n"); fflush(stdout);
  usleep(1000 * 1000);
  printf("starting write2\n"); fflush(stdout);
  usleep(1000 * 1000);
  mapped[1000] = 456;
  printf("wrote2\n"); fflush(stdout);
  usleep(1000 * 1000);
#if 1
  printf("starting read\n"); fflush(stdout);
  usleep(1000 * 1000);
  printf("read %"PRIx64"\n", mapped[1000]); fflush(stdout);
  usleep(1000 * 1000);
  printf("read %"PRIx64"\n", mapped[0]); fflush(stdout);
#endif
  usleep(1000 * 1000);
  for (i = 7; i < 16; i++) {
    printf("%x ", mapped_byte[i]); fflush(stdout);
  }
  tmp = mapped[0];
  mapped[0] = 128;
#endif
//  printf("%"PRIx64"\n", tmp);
  return 0;
}
