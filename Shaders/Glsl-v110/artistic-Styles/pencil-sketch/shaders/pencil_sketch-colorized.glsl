#version 110

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

uniform float PS_BLUR;
uniform float PS_STRENGTH;
uniform float PS_BRIGHTNESS;
uniform float PS_SATURATION;

const vec3 Y = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 texel = PS_BLUR / TextureSize;

    // [1] Base original texture sample
    vec3 srcColor = texture2D(Texture, uv).rgb;

    // Apply color saturation adjustment
    float gray = dot(srcColor, Y);
    vec3 baseColor = mix(vec3(gray), srcColor, PS_SATURATION);

    // [2] 4-tap cross blur on inverted RGB channels using direct texture sampling
    vec3 sum = vec3(1.0) - baseColor;
    sum += vec3(1.0) - texture2D(Texture, uv + texel * vec2( 1.0,  0.0)).rgb;
    sum += vec3(1.0) - texture2D(Texture, uv + texel * vec2(-1.0,  0.0)).rgb;
    sum += vec3(1.0) - texture2D(Texture, uv + texel * vec2( 0.0,  1.0)).rgb;
    sum += vec3(1.0) - texture2D(Texture, uv + texel * vec2( 0.0, -1.0)).rgb;
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