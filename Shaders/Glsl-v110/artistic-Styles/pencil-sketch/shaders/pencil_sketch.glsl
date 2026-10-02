#version 110

#pragma parameter PS_BLUR       "Blur Radius (px)"        2.0   0.5 8.0   0.1
#pragma parameter PS_STRENGTH   "Strength"                80.0 0.0 100.0 5.0
#pragma parameter PS_BRIGHTNESS "Pencil Brightness"       0.0  -1.0 1.0   0.05

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

const vec3 Y = vec3(0.299, 0.587, 0.114);

float lumaAt(vec2 sampleUv) {
    return dot(texture2D(Texture, sampleUv).rgb, Y);
}

void main() {
    vec2 texel = PS_BLUR / TextureSize;

    // [1] Sample original color and compute 0-saturation grayscale base
    vec3 original = texture2D(Texture, uv).rgb;
    float gray = dot(original, Y);
    vec3 baseGray = vec3(gray);

    // [2] 4-tap cross blur + center (5 taps total) on inverted grayscale
    float invGray = 1.0 - gray;
    float sum = invGray;
    sum += 1.0 - lumaAt(uv + texel * vec2( 1.0,  0.0));
    sum += 1.0 - lumaAt(uv + texel * vec2(-1.0,  0.0));
    sum += 1.0 - lumaAt(uv + texel * vec2( 0.0,  1.0));
    sum += 1.0 - lumaAt(uv + texel * vec2( 0.0, -1.0));
    float blurredInv = sum / 5.0;

    // [3] Color Dodge: base / (1 - blend)
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