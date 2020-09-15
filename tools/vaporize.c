#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <float.h>
#include <time.h>
#include <math.h>

#define MIN(a, b) ((a) < (b)) ? (a) : (b)
#define MAX(a, b) ((a) > (b)) ? (a) : (b)

#define MULTIPLIER 4

static float* points;
static float* weights;
static float* noiseness;
static uint32_t* priorities;
static uint32_t* heap;

static uint32_t* order; // final point index order

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
static double rd() {
  seed ^= (seed >> 12);
  seed ^= (seed << 25);
  seed ^= (seed >> 27);
  uint64_t r = seed * 2685821657736338717ULL;
  union { uint64_t i; double d; } u;
  u.i = ((0x3FFULL) << 52) | (r >> 12);
  return u.d - 1.;
}

// Heapify helper
static void heapify(uint32_t i, uint32_t n) {
  uint32_t max = i;
  uint32_t left = i * 2 + 1;
  uint32_t right = i * 2 + 2;

  if (left < n && weights[heap[left]] > weights[heap[max]]) {
    max = left;
  }

  if (right < n && weights[heap[right]] > weights[heap[max]]) {
    max = right;
  }

  if (max != i) {
    priorities[heap[i]] = max;
    priorities[heap[max]] = i;
    uint32_t temp = heap[i];
    heap[i] = heap[max];
    heap[max] = temp;
    heapify(max, n);
  }
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

static uint32_t tree_build(struct node* nodes, uint32_t offset, uint32_t count, uint32_t axis) {
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
  node->left = tree_build(nodes, offset, median, axis);
  node->right = tree_build(nodes + median + 1, median + 1 + offset, count - (median + 1), axis);
  return median + offset;
}

static void tree_query(struct node* nodes, uint32_t index, float* p, float range, void (*cb)(uint32_t, float, void*), void* ctx) {
  if (index == ~0u) return;

  struct node* node = &nodes[index];
  if (p[node->axis] + range < node->p[node->axis]) {
    tree_query(nodes, node->left, p, range, cb, ctx);
  } else if (p[node->axis] - range > node->p[node->axis]) {
    tree_query(nodes, node->right, p, range, cb, ctx);
  } else {
    float dx = p[0] - node->p[0];
    float dy = p[1] - node->p[1];
    float dz = p[2] - node->p[2];
    float d2 = dx * dx + dy * dy + dz * dz;

    if (d2 < range * range) {
      cb(node->index, d2, ctx);
    }

    tree_query(nodes, node->left, p, range, cb, ctx);
    tree_query(nodes, node->right, p, range, cb, ctx);
  }
}

// Callbacks
struct ctx_weighter { uint32_t index; float* weight; float rmax; };
static void weighter(uint32_t index, float distance2, void* userdata) {
  struct ctx_weighter* ctx = userdata;
  if (index != ctx->index) {
    float distance = sqrtf(distance2);
    float x = 1.f - (distance / (2.f * ctx->rmax));
    // Raise to 8th power
    x *= x;
    x *= x;
    x *= x;
    *ctx->weight += x;
  }
}

struct ctx_deweighter { uint32_t index; uint32_t n; float rmax; };
static void deweighter(uint32_t index, float distance2, void* userdata) {
  struct ctx_deweighter* ctx = userdata;
  if (priorities[index] != ~0u) {
    float distance = sqrtf(distance2);
    float x = 1.f - (distance / (2.f * ctx->rmax));
    // Raise to 8th power
    x *= x;
    x *= x;
    x *= x;
    weights[index] -= x;
    heapify(priorities[index], ctx->n - 1);
  }
}

// Octree

struct onode {
  uint32_t start;
  uint32_t count;
};

int cmpWeight(const void* a, const void* b) {
  uint32_t i = *(uint32_t*) a;
  uint32_t j = *(uint32_t*) b;
  if (noiseness[i] < noiseness[j]) return -1;
  else if (noiseness[i] > noiseness[j]) return 1;
  return 0;
}

static void octreeify(uint32_t parent, float center[3], float size[3], uint32_t start, uint32_t count, FILE* handle) {
  struct onode nodes[8];
  memset(nodes, 0, sizeof(nodes));

  float* c = center;
  for (uint32_t i = start; i < start + count; i++) {
    float* p = points + 3 * order[i];
    uint32_t key = ((p[0] > c[0]) << 2) | ((p[1] > c[1]) << 1) | p[2] > c[2];
    nodes[key].count++;
  }

  for (uint32_t i = 0, total = 0; i < 8; total += nodes[i++].count) {
    nodes[i].start = start + total;
  }

  for (uint32_t o = 0; o < 8 - 1; o++) {
    struct onode* node = &nodes[o];
    uint32_t i = node->start;
    uint32_t j = 0;

    // Skip any points that are already correctly in this node
    while (i < node->start + node->count) {
      float* p = points + 3 * order[i];
      uint64_t key = ((p[0] > c[0]) << 2) | ((p[1] > c[1]) << 1) | p[2] > c[2];
      if (key != o) {
        break;
      } else {
        i++;
      }
    }

    if (j <= i) j = i + 1;

    // While there are still points to add to this node
    while (i < node->start + node->count) {

      // Find the next point j that does belong in this node, starting after i
      for (;;) {
        float* p = points + 3 * order[j];
        uint64_t key = ((p[0] > c[0]) << 2) | ((p[1] > c[1]) << 1) | p[2] > c[2];
        if (key == o) {
          break;
        } else {
          j++;
        }
      }

      // Swap i and j in the final point ordering
      uint32_t temp = order[i];
      order[i] = order[j];
      order[j] = temp;

      i++;
    }
  }

  for (uint32_t o = 0; o < 8; o++) {
    struct onode* node = &nodes[o];
    qsort(order + node->start, node->count, sizeof(order[0]), cmpWeight);
  }

  // Recurse
  for (uint32_t i = 0; i < 8; i++) {
    struct onode* node = &nodes[i];
    uint32_t key = (parent << 3) | i;

    float subSize[3] = { size[0] / 2.f, size[1] / 2.f, size[2] / 2.f };
    float subCenter[3];
    subCenter[0] = center[0] - subSize[0] + ((i & 0x4) ? size[0] : 0);
    subCenter[1] = center[1] - subSize[1] + ((i & 0x2) ? size[1] : 0);
    subCenter[2] = center[2] - subSize[2] + ((i & 0x1) ? size[2] : 0);

    // Compute tight bounding box
    float minx = subCenter[0] + subSize[0];
    float maxx = subCenter[0] - subSize[0];
    float miny = subCenter[1] + subSize[1];
    float maxy = subCenter[1] - subSize[1];
    float minz = subCenter[2] + subSize[2];
    float maxz = subCenter[2] - subSize[2];
    for (uint32_t j = node->start; j < node->start + node->count; j++) {
      minx = MIN(minx, points[3 * order[j] + 0]);
      maxx = MAX(maxx, points[3 * order[j] + 0]);
      miny = MIN(miny, points[3 * order[j] + 1]);
      maxy = MAX(maxy, points[3 * order[j] + 1]);
      minz = MIN(minz, points[3 * order[j] + 2]);
      maxz = MAX(maxz, points[3 * order[j] + 2]);
    }
    subCenter[0] = (minx + maxx) / 2.f;
    subCenter[1] = (miny + maxy) / 2.f;
    subCenter[2] = (minz + maxz) / 2.f;
    subSize[0] = (maxx - minx) / 2.f;
    subSize[1] = (maxy - miny) / 2.f;
    subSize[2] = (maxz - minz) / 2.f;

    int recurse = node->count > 16384 || (size[0] > 3. || size[1] > 3. || size[2] > 3.);
    uint32_t start = node->start + 1; // Lua
    uint32_t count = node->count;

    if (node->count > 0 && !recurse) {
      fprintf(handle, "  { key = %d, start = %d, count = %d, aabb = { %f, %f, %f, %f, %f, %f }, leaf = true },\n", key, start, count, minx, maxx, miny, maxy, minz, maxz);
    } else {
      fprintf(handle, "  { key = %d, aabb = { %f, %f, %f, %f, %f, %f } },\n", key, minx, maxx, miny, maxy, minz, maxz);
    }

    if (recurse) {
      octreeify(key, subCenter, subSize, node->start, node->count, handle);
    }
  }
}

int main(int argc, char** argv) {
  if (argc < 3) {
    printf("Usage: %s [model.stl] [points/meter]\n", argv[0]);
    return 1;
  }

  float density = strtof(argv[2], NULL);
  seed = time(NULL);
  setvbuf(stdout, NULL, _IONBF, 0);

  // Read STL file

  FILE* file = fopen(argv[1], "rb");

  if (!file) {
    printf("Can't open %s\n", argv[1]);
    return 1;
  }

  fseek(file, 0, SEEK_END);
  long size = ftell(file);
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

  float min[3] = { FLT_MAX };
  float max[3] = { FLT_MIN };
  float totalArea = 0.f;
  float* areas = malloc(data->count * sizeof(float));
  for (uint32_t i = 0; i < data->count; i++) {
    float* v[3] = { data->faces[i].vertices[0], data->faces[i].vertices[1], data->faces[i].vertices[2] };
    float p[3] = { v[1][0] - v[0][0], v[1][1] - v[0][1], v[1][2] - v[0][2] };
    float q[3] = { v[2][0] - v[0][0], v[2][1] - v[0][1], v[2][2] - v[0][2] };
    float c[3] = { p[1] * q[2] - p[2] * q[1], p[2] * q[0] - p[0] * q[2], p[0] * q[1] - p[1] * q[0] };
    float length = sqrtf(c[0] * c[0] + c[1] * c[1] + c[2] * c[2]);
    areas[i] = length / 2.f;
    totalArea += areas[i];
    for (uint32_t j = 0; j < 3; j++) {
      min[j] = MIN(min[j], v[0][j]);
      min[j] = MIN(min[j], v[1][j]);
      min[j] = MIN(min[j], v[2][j]);
      max[j] = MAX(max[j], v[0][j]);
      max[j] = MAX(max[j], v[1][j]);
      max[j] = MAX(max[j], v[2][j]);
    }
  }
  float bounds[3] = { max[0] - min[0], max[1] - min[1], max[2] - min[2] };
  float center[3] = { (min[0] + max[0]) / 2.f, (min[1] + max[1]) / 2.f, (min[2] + max[2]) / 2.f };
  float volume = bounds[0] * bounds[1] * bounds[2];
  uint32_t count = totalArea * density + .5;
  uint32_t n = count * MULTIPLIER;

  printf("Count: %d\n", count);
  printf("Volume: %fm3\n", volume);
  printf("Surface Area: %fm2\n", totalArea);
  printf("Density: %fs/m\n", count / totalArea);

  points = malloc(n * 3 * sizeof(float));
  for (int i = 0; i < n; i++) {

    // Pick a random triangle weighted based on their areas
    int t = 0;
    float r = rd() * totalArea;
    while (r > areas[t] && t < data->count - 1) {
      r -= areas[t];
      t++;
    }

    // Pick a random uniform barycentric point on that triangle
    float u = rd();
    float v = rd();
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
  struct node* tree = malloc(sizeof(struct node) * n);
  for (uint32_t i = 0; i < n; i++) {
    struct node* node = &tree[i];
    memcpy(node->p, points + 3 * i, 3 * sizeof(float));
    node->left = node->right = ~0u;
    node->index = i;
  }
  uint32_t root = tree_build(tree, 0, n, 0);

  // Compute ordered weights
  weights = malloc(n * sizeof(float));
  priorities = malloc(n * sizeof(uint32_t));
  heap = malloc(n * sizeof(uint32_t));
  float rmax;
  rmax = powf(volume / (4 * sqrtf(2.f) * count), 1.f / 3.f); // 3D
  //rmax = sqrtf(totalArea / (2 * sqrtf(3.f) * count)); // 2D
  uint32_t percent = 0;
  for (uint32_t i = 0; i < n; i++) {
    weights[i] = 0.f;
    struct ctx_weighter ctx = { .index = i, .weight = &weights[i], .rmax = rmax };
    tree_query(tree, root, points + 3 * i, 2 * rmax, weighter, &ctx);
    priorities[i] = i;
    heap[i] = i;

    // While heap entry is bigger than parent, swap with parent and update priority map
    uint32_t j = i;
    uint32_t p = (j - 1) / 2;
    while (j != 0 && weights[heap[j]] > weights[heap[p]]) {
      priorities[heap[p]] = j;
      priorities[heap[j]] = p;
      uint32_t temp = heap[j];
      heap[j] = heap[p];
      heap[p] = temp;
      j = p;
      p = (j - 1) / 2;
    }

    uint32_t prc = (float) i / (n - 1) * 10.f;
    if (prc != percent) {
      percent = prc;
      printf(".");
    }
  }
  printf("\n");

  // Sample elimination:
  // Use heap to find heaviest element and remove it
  // Do a range query and reduce the weight of its neighbors
  uint32_t i = 0;
  order = malloc(count * sizeof(uint32_t));
  noiseness = malloc(n * sizeof(float));
  while (n > 0) {
    uint32_t index = heap[0];
    priorities[index] = ~0u;

    if (n > 1) {
      heap[0] = heap[n - 1];
      priorities[heap[0]] = 0;
      heapify(0, n - 1);
      struct ctx_deweighter ctx = { .index = index, .n = n - 1, .rmax = rmax };
      tree_query(tree, root, points + 3 * index, 2 * rmax, deweighter, &ctx);
    }

    if (n <= count) {
      order[n - 1] = index;
      noiseness[index] = (float) (n - 1) / count;
    }

    n--;

    uint32_t prc = (float) i / (count * MULTIPLIER) * 10.f;
    if (prc != percent) {
      percent = prc;
      printf(".");
    }
    i++;
  }
  printf("\n");

  FILE* meta = fopen("points.lua", "w+");
  if (!meta) {
    printf("Can't open %s\n", "points.lua");
    return 1;
  }


  float halfBounds[3] = { bounds[0] / 2.f, bounds[1] / 2.f, bounds[2] / 2.f };
  float minx = center[0] - halfBounds[0];
  float maxx = center[0] + halfBounds[0];
  float miny = center[1] - halfBounds[1];
  float maxy = center[1] + halfBounds[1];
  float minz = center[2] - halfBounds[2];
  float maxz = center[2] + halfBounds[2];
  fprintf(meta, "return {\n  { key = 1, aabb = { %f, %f, %f, %f, %f, %f } },\n", minx, maxx, miny, maxy, minz, maxz);
  octreeify(0x1, center, halfBounds, 0, count, meta);
  fputs("}\n", meta);
  fclose(meta);

  FILE* bin = fopen("points.bin", "wb+");
  if (!bin) {
    printf("Can't open %s\n", "points.bin");
    return 1;
  }

  for (uint32_t i = 0; i < count; i++) {
    fwrite(points + 3 * order[i], 1, 12, bin);
    fwrite(noiseness + order[i], 1, 4, bin);
  }

  fclose(bin);

  free(data);
  free(points);
  free(weights);
  free(noiseness);
  free(priorities);
  free(heap);
  free(order);
  return 0;
}
