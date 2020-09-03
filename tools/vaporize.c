#include <stdio.h>
#include <stdlib.h>

#pragma pack(push,1)
struct stl {
  char header[80];
  unsigned count;
  struct {
    float normal[3];
    float positions[9];
    short padding;
  } faces[];
};
#pragma pack(pop)

int main(int argc, char** argv) {
  if (argc < 2) {
    printf("Usage: %s [model.stl]\n", argv[0]);
    return 1;
  }

  FILE* file = fopen(argv[1], "rb");

  if (!file) {
    printf("Can't open %s\n", argv[1]);
    return 1;
  }

  fseek(file, 0, SEEK_END);
  int size = ftell(file);
  fseek(file, 0, SEEK_SET);

  struct stl* data = calloc(1, size);

  if (!data) {
    printf("Out of memory\n");
    return 1;
  }

  if (fread(data, 1, size, file) < size) {
    printf("Can't read %s\n", argv[1]);
  }

  //

  free(data);
  fclose(file);

  return 0;
}
