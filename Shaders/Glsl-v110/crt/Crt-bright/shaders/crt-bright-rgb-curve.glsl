#version 110

#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
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
uniform float BARREL_DISTORTION;
uniform float SCAN_LOW;
uniform float SCAN_HIGH;
uniform float MASK_LOW;
uniform float MASK_HIGH;
uniform float GAMMA_BOOST;
#else
#define BARREL_DISTORTION 0.15
#define SCAN_LOW 0.8
#define SCAN_HIGH 0.3
#define MASK_LOW 0.5
#define MASK_HIGH 0.2
#define GAMMA_BOOST 1.0
#endif

#define PI 3.141592653589793
#define TAU 6.283185307179586

void main() {

    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // [كيرف 20 الجديد] حساب نصف القطر المربع ومعادلة الانحناء البرميلي السريعة
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));

    vec2 texCoord = (p_curved + 0.5) / sc;

    vec2 bounds = step(abs(p_curved), vec2(0.5));

    vec3 res = texture2D(Texture, texCoord).rgb;
    res *= bounds.x * bounds.y;

    float l = max(max(res.r, res.g), res.b);

    float infl = mix(SCAN_LOW, SCAN_HIGH, l);
    float infl2 = mix(MASK_LOW, MASK_HIGH, l);

    // 1. Calculate straight scanlines
    float scan = infl * sin((uv.y * TextureSize.y - 0.25) * TAU);
    
    // 2. RGB Aperture Grille Mask using screen subpixels
    float mod_x = mod(gl_FragCoord.x, 3.0);
    vec3 msk = vec3(-infl2); 

    if (mod_x < 1.0) {
        msk.r = infl2; 
    } else if (mod_x < 2.0) {
        msk.g = infl2; 
    } else {
        msk.b = infl2; 
    }

    // 3. Apply scanlines and the RGB mask 
    res += res * scan;
    res += res * msk;

    // 4. Gamma correction
    res = mix(res, sqrt(res), GAMMA_BOOST);

    gl_FragColor = vec4(res, 1.0);
}
#endif