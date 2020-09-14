#ifdef VERTEX
  vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
    vertex.xyz -= lovrNormal * .01;
    return projection * transform * vertex;
  }
#endif

#ifdef PIXEL
  vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
    return vec4(1.);
  }
#endif
