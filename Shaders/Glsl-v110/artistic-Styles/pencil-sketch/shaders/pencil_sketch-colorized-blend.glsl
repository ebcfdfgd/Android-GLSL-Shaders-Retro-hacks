#version 110

#pragma parameter SGPT_BLEND_LEVEL "SGPT Blend Level"      1.0   0.0 1.0   0.05
#pragma parameter PS_BLUR          "Blur Radius (px)"        2.0   0.5 8.0   0.1
#pragma parameter PS_STRENGTH      "Strength"                80.0 0.0 100.0 5.0
#pragma parameter PS_BRIGHTNESS    "Pencil Brightness"       0.0  -1.0 1.0   0.05
#pragma parameter PS_SATURATION    "Color Saturation"        1.0   1.0 2.0   0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;

uniform float SGPT_BLEND_LEVEL;
uniform float PS_BLUR;
uniform float PS_STRENGTH;
uniform float PS_BRIGHTNESS;
uniform float PS_SATURATION;

const vec3 Y = vec3(0.299, 0.587, 0.114);

// SGPT sampling function
vec3 sgptSample(vec2 sampleUv) {
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0);
    vec3 C = texture2D(Texture, sampleUv).rgb;
    vec3 L = texture2D(Texture, sampleUv - dx).rgb;
    vec3 R = texture2D(Texture, sampleUv + dx).rgb;

    vec3 diffL = C - L;
    vec3 diffR = C - R;

    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    vec3 result = (wR < wL) ? (C - 0.5 * SGPT_BLEND_LEVEL * diffR)
                           : (C - 0.5 * SGPT_BLEND_LEVEL * diffL);

    return clamp(result, min(C, min(L, R)), max(C, max(L, R)));
}

void main() {
    vec2 texel = PS_BLUR / TextureSize;

    // [1] Base SGPT result in full RGB
    vec3 sgptColor = sgptSample(uv);

    // Apply color saturation adjustment
    float gray = dot(sgptColor, Y);
    vec3 baseColor = mix(vec3(gray), sgptColor, PS_SATURATION);

    // [2] 4-tap cross blur on inverted RGB channels
    vec3 sum = vec3(1.0) - baseColor;
    sum += vec3(1.0) - sgptSample(uv + texel * vec2( 1.0,  0.0));
    sum += vec3(1.0) - sgptSample(uv + texel * vec2(-1.0,  0.0));
    sum += vec3(1.0) - sgptSample(uv + texel * vec2( 0.0,  1.0));
    sum += vec3(1.0) - sgptSample(uv + texel * vec2( 0.0, -1.0));
    vec3 blurredInv = sum / 5.0;

    // [3] RGB Per-Channel Color Dodge Effect (Color Pencil)
    vec3 sketch = baseColor / max(vec3(1.0) - blurredInv, vec3(0.004));
    sketch = clamp(sketch, 0.0, 1.0);

    // [4] Apply Brightness
    sketch = clamp(sketch + vec3(PS_BRIGHTNESS), 0.0, 1.0);

    // [5] Mix full base color with colored pencil sketch
    float amount = clamp(PS_STRENGTH / 100.0, 0.0, 1.0);
    vec3 finalColor = mix(baseColor, sketch, amount);

    gl_FragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}
#endif