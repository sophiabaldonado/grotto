#ifdef VERTEX
  out float alpha;

  layout(std430, binding = 0) readonly buffer Points {
    vec4 points[];
  };

  layout(std430, binding = 1) readonly buffer Sizes {
    float sizes[];
  };

  uniform vec3 head;
  uniform vec3 world;

  vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
    vec4 point = points[gl_VertexID];
    /*float lod = max(distance(head, point.xyz) / 2. - 1., 0.);
    float threshold = 1. / pow(2., lod);
    float factor = sizes[gl_VertexID] * (1. - smoothstep(threshold * .95, threshold, point.w));
    if (factor < .01) {
      return vec4(0.);
    }*/
    vec4 p = lovrProjection * lovrView * vec4(point.xyz + world, 1.);
    alpha = sizes[gl_VertexID];
    gl_PointSize = 2. / p.w;
    return p;
  }
#endif

#ifdef PIXEL
  in float alpha;
  vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
    if (length(2. * gl_PointCoord - 1.) > 1.f) discard;
    return vec4(alpha);
  }
#endif
