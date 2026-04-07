#version 110

/*
    CRT-LIGHT-ULTIMATE (Pro-E Edition)
    - Color Profiles: Europe (EBU), America (SMPTE-C), Japan (NTSC-J).
    - Focused Glow & Halation on High Luminance.
    - Optimized for Speed & Color Accuracy.
*/

// Color Profile Select: 0: Default, 1: Europe (EBU), 2: America (SMPTE), 3: Japan (NTSC)
#pragma parameter CLU_PROFILE "Color Profile (EU, US, JP)" 0.0 0.0 3.0 1.0

#pragma parameter CLU_CONTRAST "CRT Contrast" 1.10 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "CRT Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "CRT Brightness" 1.1 1.0 2.0 0.05
#pragma parameter CLU_GLOW "CRT Glow Strength" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "CRT Halation Strength" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.20 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    TEX0 = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
varying vec2 TEX0;

#ifdef PARAMETER_UNIFORM
uniform float CLU_PROFILE, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
#endif

// Color Transformation Matrices
const mat3 EBU_RGB = mat3(1.0, 0.0, 0.0,  0.0, 1.0, 0.0,  0.0, 0.0, 1.0); // Standard
const mat3 SMPTE_RGB = mat3(0.95, 0.05, 0.0,  0.02, 0.98, 0.0,  0.0, 0.05, 0.95); // Warmer US
const mat3 NTSC_J_RGB = mat3(0.9, 0.1, 0.0,  0.05, 0.9, 0.05,  0.0, 0.1, 1.1); // Cooler Japan

void main() {
    vec4 texel = texture2D(Texture, TEX0);
    vec3 res = texel.rgb;

    // 1. Linearize
    res = res * res;

    // 2. Apply Color Profile
    if (CLU_PROFILE > 0.5 && CLU_PROFILE < 1.5) {
        // Europe (EBU) - Neutral/Natural
        res = res * mat3(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0);
    } 
    else if (CLU_PROFILE > 1.5 && CLU_PROFILE < 2.5) {
        // America (SMPTE-C) - Richer Reds/Skin Tones
        res = clamp(res * SMPTE_RGB, 0.0, 1.0);
    } 
    else if (CLU_PROFILE > 2.5) {
        // Japan (NTSC-J) - Bluish White / Cool Highs
        res = clamp(res * NTSC_J_RGB, 0.0, 1.0);
    }

    // 3. Contrast & Saturation
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    float luma = dot(res, vec3(0.299, 0.587, 0.114)); 
    res = mix(vec3(luma), res, CLU_SATURATION);

    // 4. Black Depth
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    // 5. High-Luma Focused Glow (E-Square Targeting)
    vec3 glow_mask = pow(max(res, 0.0), vec3(4.0));
    res += glow_mask * (CLU_GLOW + glow_mask * CLU_HALATION);
    
    res *= CLU_BRIGHT;

    // 6. Output Gamma (Fast Sqrt)
    gl_FragColor = vec4(sqrt(max(res, 0.0)), texel.a);
}
#endif