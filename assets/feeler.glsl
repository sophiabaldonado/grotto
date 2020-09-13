layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) readonly buffer Points {
  vec4 points[];
};

layout(std430, binding = 1) buffer Sizes {
  float sizes[];
};

uniform int offset;
uniform vec3 hands[2];
uniform float dt;

void compute() {
  uint id = gl_WorkGroupID.x;
  uint index = uint(offset) + id;

  vec3 point = points[index].xyz;
  float leftDistance = distance(hands[0], point);
  float rightDistance = distance(hands[1], point);
  float d = min(leftDistance, rightDistance);

  if (d < .5) {
    float factor = pow(clamp(1.f - d / .3, 0., 1.), 2.f);
    sizes[index] = min(sizes[index] + dt * 8.f * factor, 1.f);
  }
}
