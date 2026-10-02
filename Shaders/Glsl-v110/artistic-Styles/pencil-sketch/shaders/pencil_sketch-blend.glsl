#version 110

#pragma parameter SGPT_BLEND_LEVEL "SGPT Blend Level"      1.0   0.0 1.0   0.05
#pragma parameter PS_BLUR          "Blur Radius (px)"        2.0   0.5 8.0   0.1
#pragma parameter PS_STRENGTH      "Strength"                80.0 0.0 100.0 5.0
#pragma parameter PS_BRIGHTNESS    "Pencil Brightness"       0.0  -1.0 1.0   0.05

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

    // [1] Base SGPT result at current pixel & 0-saturation grayscale base
    vec3 sgptColor = sgptSample(uv);
    float gray = dot(sgptColor, Y);
    vec3 baseGray = vec3(gray);

    // [2] 4-tap cross blur + center (5 taps total) on inverted SGPT neighbors
    float sum = 1.0 - gray;
    sum += 1.0 - dot(sgptSample(uv + texel * vec2( 1.0,  0.0)), Y);
    sum += 1.0 - dot(sgptSample(uv + texel * vec2(-1.0,  0.0)), Y);
    sum += 1.0 - dot(sgptSample(uv + texel * vec2( 0.0,  1.0)), Y);
    sum += 1.0 - dot(sgptSample(uv + texel * vec2( 0.0, -1.0)), Y);
    float blurredInv = sum / 5.0;

    // [3] Color Dodge effect
    float sketch = gray / max(1.0 - blurredInv, 0.004);
    sketch = clamp(sketch, 0.0, 1.0);

    // [4] Apply Brightness
    sketch = clamp(sketch + PS_BRIGHTNESS, 0.0, 1.0);
    vec3 sketchColor = vec3(sketch);

    // [5] Mix with grayscale base (0 saturation at strength = 0)
    float amount = clamp(PS_STRENGTH / 100.0, 0.0, 1.0);
    vec3 finalColor = mix(baseGray, sketchColor, amount);

    gl_FragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}
#endif