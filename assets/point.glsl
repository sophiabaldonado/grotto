#ifdef VERTEX
  out float alpha;

  layout(std430, binding = 0) readonly buffer Points {
    vec4 points[];
  };

  layout(std430, binding = 1) readonly buffer Sizes {
    float sizes[];
  };

  uniform vec3 head;

  float lod() {
    float d = distance(head, points[gl_VertexID].xyz);
    float pointFill = pow(1. - clamp(d / 2., 0., 1.), 3.);
    return 1. - smoothstep(pointFill - .05, pointFill, 1. - points[gl_VertexID].w);
  }

  vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
    alpha = sizes[gl_VertexID];
    gl_PointSize = sizes[gl_VertexID];
    return projection * transform * vec4(points[gl_VertexID].xyz, 1.);
  }
#endif

#ifdef PIXEL
  in float alpha;
  vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
    return vec4(alpha);
  }
#endif
