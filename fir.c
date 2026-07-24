#define N 1000
#define N_DEC 999 // = N - 1

#include "dynamatic/Integration.h"
#include "stdlib.h"

int fir(int di[N], int idx[N]) {
  int tmp = 0;
  for (unsigned i = 0; i < N; i++)
    tmp += idx[i] * di[N_DEC - i];
  return tmp;
}

int main(void) {
  int di[N];
  int idx[N];

  srand(13);
  for (int j = 0; j < N; ++j) {
    di[j] = rand() % 100;
    idx[j] = rand() % 100;
  }

  CALL_KERNEL(fir, di, idx);
  return 0;
}
