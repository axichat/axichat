#version 320 es
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uRectOrigin;
uniform vec2 uRectSize;
uniform vec4 uGlyphRect;
uniform vec2 uDotCenter;
uniform float uDotRadius;
uniform float uProgress;
uniform float uEdge;
uniform float uSpread;
uniform vec4 uColor;
uniform sampler2D uGlyphSdf;

out vec4 fragColor;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 local = frag - uRectOrigin;
  if (local.x < 0.0 || local.y < 0.0 ||
      local.x > uRectSize.x || local.y > uRectSize.y) {
    discard;
  }

  vec2 glyphMin = uGlyphRect.xy;
  vec2 glyphMax = uGlyphRect.xy + uGlyphRect.zw;
  float glyphSdf = 1.0;
  if (local.x >= glyphMin.x && local.y >= glyphMin.y &&
      local.x <= glyphMax.x && local.y <= glyphMax.y) {
    vec2 uv = (local - glyphMin) / uGlyphRect.zw;
    glyphSdf = texture(uGlyphSdf, uv).r;
  }

  float dist = length(local - uDotCenter) - uDotRadius;
  float circleSdf = clamp(0.5 + dist / (2.0 * uSpread), 0.0, 1.0);
  float mixedSdf = mix(circleSdf, glyphSdf, uProgress);
  float alpha = smoothstep(0.5 + uEdge, 0.5 - uEdge, mixedSdf);
  fragColor = vec4(uColor.rgb, uColor.a * alpha);
}
