// PUBLIC DOMAIN CRT FAST-SCAN V2.2 - LEGACY 110
// VERSION: GLSL 110 (Max Compatibility)
// MODES: 1 = Sony Trinitron, 2 = Slot Mask

#pragma parameter hardScan "Scanline Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter hardPix "Pixel Hardness" -3.0 -20.0 0.0 1.0
#pragma parameter warpX "Curvature X" 0.03 0.0 0.125 0.01
#pragma parameter warpY "Curvature Y" 0.04 0.0 0.125 0.01
#pragma parameter maskDark "Shadow Mask Dark" 0.5 0.0 2.0 0.1
#pragma parameter maskLight "Shadow Mask Light" 1.5 0.0 2.0 0.1
#pragma parameter shadowMask "Mask Type (1-2)" 2.0 1.0 2.0 1.0
#pragma parameter brightBoost "Brightness Boost" 1.2 0.0 2.0 0.05
#pragma parameter bloomAmount "Glow/Bloom Strength" 0.15 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec4 TEX0;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec4 TEX0;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform float hardScan, hardPix, warpX, warpY, maskDark, maskLight, shadowMask, brightBoost, bloomAmount;
#else
#define hardScan -8.0
#define hardPix -3.0
#define warpX 0.031
#define warpY 0.041
#define maskDark 0.5
#define maskLight 1.5
#define shadowMask 2.0
#define brightBoost 1.0
#define bloomAmount 0.15
#endif

vec2 Warp(vec2 pos) {
    pos = pos * 2.0 - 1.0;
    pos *= vec2(1.0 + (pos.y * pos.y) * warpX, 1.0 + (pos.x * pos.x) * warpY);
    return pos * 0.5 + 0.5;
}

vec3 Mask(vec2 pos) {
    vec3 m = vec3(maskDark);
    
    // Mask 1: Aperture Grille
    if (shadowMask < 1.5) {
        float x = fract(pos.x * 0.3333);
        if (x < 0.333) m.r = maskLight;
        else if (x < 0.666) m.g = maskLight;
        else m.b = maskLight;
    } 
    // Mask 2: SLOT MASK
    else {
        float x = pos.x;
        float y = pos.y;
        float odd = 0.0;
        if (fract(x * 0.1666) < 0.5) odd = 1.0;
        if (fract((y + odd) * 0.5) < 0.5) return m; 
        
        x = fract(x * 0.3333);
        if (x < 0.333) m.r = maskLight;
        else if (x < 0.666) m.g = maskLight;
        else m.b = maskLight;
    }
    return m;
}

void main() {
    vec2 uv = TEX0.xy * (TextureSize.xy / InputSize.xy);
    vec2 pos = Warp(uv);
    vec2 fetchPos = pos * (InputSize.xy / TextureSize.xy);
    
    vec3 col = texture2D(Texture, fetchPos).rgb;
    col *= brightBoost;
    
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float beam = fract(pos.y * InputSize.y); 
    float scanline = exp2(hardScan * pow(abs(beam - 0.5), 2.0));
    
    vec3 final = col * mix(scanline, 1.0, lum * bloomAmount);
    
    // تطبيق الماسك (1 أو 2 فقط)
    final *= Mask(gl_FragCoord.xy);

    // حدود الشاشة
    if (pos.x < 0.0 || pos.x > 1.0 || pos.y < 0.0 || pos.y > 1.0) final = vec3(0.0);

    gl_FragColor = vec4(final, 1.0);
}
#endif