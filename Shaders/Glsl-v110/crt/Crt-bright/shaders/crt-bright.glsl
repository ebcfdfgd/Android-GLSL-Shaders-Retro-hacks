#version 110

#pragma parameter SCAN_LOW "Scanline Intensity (Dark Scenes)" 0.8 0.0 1.0 0.05
#pragma parameter SCAN_HIGH "Scanline Intensity (Bright Scenes)" 0.3 0.0 1.0 0.05
#pragma parameter MASK_LOW "Mask Intensity (Dark Scenes)" 0.5 0.0 1.0 0.05
#pragma parameter MASK_HIGH "Mask Intensity (Bright Scenes)" 0.2 0.0 1.0 0.05
#pragma parameter GAMMA_BOOST "Gamma Brightness Boost" 0.0 -1.0 1.0 0.05

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
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform vec2 OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float SCAN_LOW;
uniform float SCAN_HIGH;
uniform float MASK_LOW;
uniform float MASK_HIGH;
uniform float GAMMA_BOOST;
#else
#define SCAN_LOW 0.8
#define SCAN_HIGH 0.3
#define MASK_LOW 0.5
#define MASK_HIGH 0.2
#define GAMMA_BOOST 1.0
#endif

#define PI 3.141592653589793
#define TAU 6.283185307179586

void main() {
  
    vec3 res = texture2D(Texture, uv).rgb;

    float l = max(max(res.r, res.g), res.b);


    float infl = mix(SCAN_LOW, SCAN_HIGH, l);
    float infl2 = mix(MASK_LOW, MASK_HIGH, l);


    vec2 scale = TextureSize / InputSize;
    vec2 maskpos = uv * scale * OutputSize;

 
    float scan = infl * sin((uv.y * TextureSize.y - 0.25) * TAU);
    float msk = infl2 * sin(maskpos.x * PI);

 
    res += res * scan;
    res += res * msk;


    res = mix(res, sqrt(res), GAMMA_BOOST);

    gl_FragColor = vec4(res, 1.0);
}
#endif