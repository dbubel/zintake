#include <unistd.h>

int num_cores() {
  long num_cores = sysconf(_SC_NPROCESSORS_ONLN);
  return 0;
}
