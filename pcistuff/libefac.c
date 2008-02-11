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
#include "libefac.h"

#define VENDOR 7
#define DEVICE 7
#ifdef DEBUG
#define dbgprintf(...) printf(__VA_ARGS__);
#else
#define dbgprintf(...)
#endif

static int find_device(off_t *map_base, size_t *map_size) {
  int found = 0;
  struct pci_access *pci_acc = pci_alloc();
  struct pci_dev *device;
  pci_init(pci_acc);
  pci_scan_bus(pci_acc);
  device = pci_acc->devices;
  while (device) {
    pci_fill_info(device, PCI_FILL_IDENT | PCI_FILL_BASES | PCI_FILL_SIZES);
    dbgprintf("device: %x %x %lx %lx\n", device->vendor_id, device->device_id,
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

static void *map_physical(void * dst, off_t base, size_t size) {
  void *mapped;
  int flags = MAP_SHARED;
  int memfd = open("/dev/mem", O_RDWR);
  if (memfd == -1) {
    dbgprintf("could not open '/dev/mem'\n");
    return NULL;
  }
  if (dst) flags |= MAP_FIXED;
  mapped = mmap(dst, size, PROT_READ | PROT_WRITE, flags, memfd, base);
  close(memfd);
  return mapped;
}

static void set_mtrr(off_t base, size_t size, char *mode) {
  int fd;
  char buffer[256];
  snprintf(buffer, sizeof(buffer),
           "base=0x%08"PRIx64" size=0x%08"PRIx64" type=%s\n",
           (uint64_t)base, (uint64_t)size, mode);
  fd = open("/proc/mtrr", O_WRONLY);
  write(fd, buffer, strlen(buffer));
  close(fd);
}

#define REGCNT 8
#define REGSZ 4096
#define EFAC_ALIGNED(n, t, v) t v __attribute__((aligned(n)))

EFAC_ALIGNED(REGSZ, volatile uint8_t, efac_regs[REGCNT * REGSZ]);
int efac_idx;

int efac_init(void) {
  size_t map_size = 0;
  off_t map_base = 0;
  volatile uint8_t *mapped;
  if (!find_device(&map_base, &map_size)) {
    dbgprintf("device not found!\n");
    return 0;
  }
  if (!map_base || map_size < REGCNT * REGSZ) {
    dbgprintf("device invalid!\n");
    return 0;
  }
  map_size = REGCNT * REGSZ;
  mapped = map_physical((void *)efac_regs, map_base, map_size);
  if (!mapped) {
    dbgprintf("mmap of PCI device failed\n");
    return 0;
  }
  dbgprintf("setting MTRR (check /proc/mtrr if it worked)\n");
  set_mtrr(map_base, map_size, "write-combining");
  return 1;
}

void efac_save(int reg, uint32_t buf[512]) {
  volatile uint32_t *regb = (volatile uint32_t *)&efac_regs[reg * 4096];
  int i;
  for (i = 0; i < 512; i++)
    buf[i] = regb[512 + i];
}

void efac_restore(int reg, const uint32_t buf[512]) {
  volatile uint32_t *regb = (volatile uint32_t *)&efac_regs[reg * 4096];
  int i;
  for (i = 0; i < 512; i++)
    regb[512 + i] = buf[i];
}
