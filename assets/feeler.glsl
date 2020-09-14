layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) readonly buffer Points {
  vec4 points[];
};

layout(std430, binding = 1) buffer Sizes {
  float sizes[];
};

uniform int offset;
uniform vec3 lights[4];
uniform float dt;

void compute() {
  uint id = gl_WorkGroupID.x;
  uint index = uint(offset) + id;

  vec3 point = points[index].xyz;
  float d0 = distance(lights[0], point);
  float d1 = distance(lights[1], point);
  float d2 = distance(lights[2], point);
  float d = min(min(d0, d1), d2);

  if (d < .3) {
    float factor = pow(clamp(1.f - d / .3, 0., 1.), 2.f);
    sizes[index] = min(sizes[index] + dt * 8.f * factor, 1.f);
  }
}
