#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <math.h>

// STL
#pragma pack(push,1)
struct stl {
  char header[80];
  uint32_t count;
  struct {
    float normal[3];
    float vertices[3][3];
    short padding;
  } faces[];
};
#pragma pack(pop)

// RNG
static uint64_t wangHash64(uint64_t key) {
  key = (~key) + (key << 21); // key = (key << 21) - key - 1;
  key = key ^ (key >> 24);
  key = (key + (key << 3)) + (key << 8); // key * 265
  key = key ^ (key >> 14);
  key = (key + (key << 2)) + (key << 4); // key * 21
  key = key ^ (key >> 28);
  key = key + (key << 31);
  return key;
}

static uint64_t seed;
static double random() {
  seed ^= (seed >> 12);
  seed ^= (seed << 25);
  seed ^= (seed >> 27);
  uint64_t r = seed * 2685821657736338717ULL;
  union { uint64_t i; double d; } u;
  u.i = ((0x3FFULL) << 52) | (r >> 12);
  return u.d - 1.;
}

// k-d tree
// Used blender as reference (source/blender/blenlib/intern/kdtree_impl.h)
struct node {
  float p[3];
  uint32_t left;
  uint32_t right;
  uint32_t index;
  uint32_t axis;
};

struct neighbor {
  uint32_t index;
  float distance;
};

struct tree {
  uint32_t count;
  uint32_t root;
  struct node* nodes;
};

static void tree_insert(struct tree* tree, float* p, uint32_t index) {
  struct node* node = &tree->nodes[tree->count++];
  node->left = ~0u;
  node->right = ~0u;
  memcpy(node->p, p, 3 * sizeof(float));
  node->index = index;
  node->axis = 0;
}

static uint32_t balance(struct node* nodes, uint32_t offset, uint32_t count, uint32_t axis) {
  if (count == 0) {
    return ~0u;
  } else if (count == 1) {
    return offset;
  }

  uint32_t left = 0;
  uint32_t right = count - 1;
  uint32_t median = count / 2;

  while (right > left) {
    uint32_t i = left - 1;
    uint32_t j = right;
    float x = nodes[right].p[axis];

    for (;;) {
      while (nodes[++i].p[axis] < x);
      while (nodes[--j].p[axis] > x && j > left);
      if (i >= j) { break; }

      struct node temp = nodes[i];
      size_t copySize = sizeof(struct node) - sizeof(uint32_t);
      memcpy(&nodes[i], &nodes[j], copySize);
      memcpy(&nodes[j], &temp, copySize);
    }

    struct node temp = nodes[i];
    size_t copySize = sizeof(struct node) - sizeof(uint32_t);
    memcpy(&nodes[i], &nodes[right], copySize);
    memcpy(&nodes[right], &temp, copySize);

    if (i >= median) { right = i - 1; }
    if (i <= median) { left = i + 1; }
  }

  struct node* node = &nodes[median];
  node->axis = axis;
  axis = (axis + 1) % 3;
  node->left = balance(nodes, offset, median, axis);
  node->right = balance(nodes + median + 1, median + 1 + offset, count - (median + 1), axis);
  return median + offset;
}

static void tree_balance(struct tree* tree) {
  tree->root = balance(tree->nodes, 0, tree->count, 0);
}

static void range_query(struct node* nodes, uint32_t index, float* p, float range) {
  if (index == ~0u) return;
  struct node* node = &nodes[index];
  if (p[node->axis] + range < node->p[node->axis]) {
    range_query(nodes, node->left, p, range);
  } else if (p[node->axis] - range > node->p[node->axis]) {
    range_query(nodes, node->right, p, range);
  } else {
    float dx = p[0] - node->p[0];
    float dy = p[1] - node->p[1];
    float dz = p[2] - node->p[2];
    float d2 = dx * dx + dy * dy + dz * dz;
    if (d2 < range * range) {
      //
    }

    range_query(nodes, node->left, p, range);
    range_query(nodes, node->right, p, range);
  }
}

static void tree_range_query(struct tree* tree, float* p, float range) {
  range_query(tree->nodes, tree->root, p, range);
}

int main(int argc, char** argv) {
  if (argc < 3) {
    printf("Usage: %s [model.stl] [n]\n", argv[0]);
    return 1;
  }

  int n = atoi(argv[2]);
  seed = time();

  // Read STL file

  FILE* file = fopen(argv[1], "rb");

  if (!file) {
    printf("Can't open %s\n", argv[1]);
    return 1;
  }

  fseek(file, 0, SEEK_END);
  int size = ftell(file);
  fseek(file, 0, SEEK_SET);

  struct stl* data = calloc(1, size);
  if (fread(data, 1, size, file) < size) {
    printf("Can't read %s\n", argv[1]);
  }

  fclose(file);

  // Compute the area of the mesh
  // For each triangle, the area is the length of the cross product of 2 of its vectors divided by 2
  // Sum the area of all the triangles to get the total area
  // Also store the area for each triangle

  float totalArea = 0.f;
  float* areas = malloc(data->count * sizeof(float));
  for (unsigned i = 0; i < data->count; i++) {
    float* v[3] = { data->faces[i].vertices[0], data->faces[i].vertices[1], data->faces[i].vertices[2] };
    float p[3] = { v[1][0] - v[0][0], v[1][1] - v[0][1], v[1][2] - v[0][2] };
    float q[3] = { v[2][0] - v[0][0], v[2][1] - v[0][1], v[2][2] - v[0][2] };
    float c[3] = { p[1] * q[2] - p[2] * q[1], p[2] * q[0] - p[0] * q[2], p[0] * q[1] - p[1] * q[0] };
    float length = sqrtf(c[0] * c[0] + c[1] * c[1] + c[2] * c[2]);
    areas[i] = length / 2.f;
    totalArea += areas[i];
  }

  float* points = malloc(n * 3 * sizeof(float));

  for (int i = 0; i < n; i++) {

    // Pick a random triangle weighted based on their areas
    int t = 0;
    float r = random() * totalArea;
    while (r > areas[t]) {
      r -= areas[t];
      t++;
    }

    // Pick a random uniform barycentric point on that triangle
    float u = random();
    float v = random();
    if (u + v > 1.f) {
      u = 1.f - u;
      v = 1.f - v;
    }
    float* p[3] = { data->faces[t].vertices[0], data->faces[t].vertices[1], data->faces[t].vertices[2] };
    float a[3] = { p[0][0], p[0][1], p[0][2] };
    float b[3] = { p[1][0] - a[0], p[1][1] - a[1], p[1][2] - a[2] };
    float c[3] = { p[2][0] - a[0], p[2][1] - a[1], p[2][2] - a[2] };
    points[i * 3 + 0] = a[0] + u * b[0] + v * c[0];
    points[i * 3 + 1] = a[1] + u * b[1] + v * c[1];
    points[i * 3 + 2] = a[2] + u * b[2] + v * c[2];
  }

  // Put points into kdtree
  struct tree tree;
  tree.nodes = malloc(sizeof(struct node) * n);
  tree.count = 0;

  // Insert points into the tree
  for (uint32_t i = 0; i < n; i++) {
    tree_insert(&tree, points + 3 * i, i);
  }

  tree_balance(&tree);

  float p[3] = { 0.f, 0.f, -10.f };
  tree_range_query(&tree, p, 5.f);

  FILE* bin = fopen("points.bin", "wb+");
  if (!bin) {
    printf("Can't open %s\n", "points.bin");
    return 1;
  }

  fwrite(points, sizeof(char), n * 3 * sizeof(float), bin);
  fclose(bin);
  free(data);
  return 0;
}
