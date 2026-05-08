#version 110

/* FAST-LCD-TURBO-V4
    - OPTIMIZED: Fast Gamma Approximation (x^2 and sqrt).
    - CLEANED: Removed BGR, BlackLevel, and Subpix params.
    - PERFORMANCE: Optimized for Mali/Adreno GPUs.
*/

// --- PARAMETERS ---
#pragma parameter gain       "LCD Gain" 1.0 0.5 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize, OutputSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float gain;
#endif

// دالة التنعيم S-Curve
vec3 S(vec3 x, float dx, float d) {
    vec3 h = clamp((x + dx * 0.5) / d, -1.0, 1.0);
    vec3 l = clamp((x - dx * 0.5) / d, -1.0, 1.0);
    return d * (h * (1.0 - 0.333 * h * h) - l * (1.0 - 0.333 * l * l)) / dx;
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    vec2 pos = vTexCoord / ps - 0.5;
    vec2 fp = floor(pos);
    vec2 uv00 = (fp + 0.5) * ps;
    
    // --- تسريع الجاما (Fast Input Gamma ~2.0) ---
    vec3 c00 = texture2D(Texture, uv00).rgb * gain; c00 *= c00;
    vec3 c10 = texture2D(Texture, uv00 + vec2(ps.x, 0.0)).rgb * gain; c10 *= c10;
    vec3 c01 = texture2D(Texture, uv00 + vec2(0.0, ps.y)).rgb * gain; c01 *= c01;
    vec3 c11 = texture2D(Texture, uv00 + ps).rgb * gain; c11 *= c11;

    float sx = (pos.x - fp.x) * 3.0;
    float rx = (InputSize.x / OutputSize.x) * 3.0;
    float sy = (pos.y - fp.y);
    float ry = (InputSize.y / OutputSize.y);

    // فرشاة التلوين (Subpixel Phosphors)
    vec3 lc = S(vec3(sx + 1.0, sx, sx - 1.0), rx, 1.5);
    vec3 rc = S(vec3(sx - 2.0, sx - 3.0, sx - 4.0), rx, 1.5);
    
    float tw = S(vec3(sy), ry, 0.63).x;
    float bw = S(vec3(sy - 1.0), ry, 0.63).x;

    vec3 res = (c00 * lc * tw) + (c10 * rc * tw) + (c01 * lc * bw) + (c11 * rc * bw);
    
    // --- تسريع الجاما النهائي (Fast Output Gamma ~2.0) ---
    gl_FragColor = vec4(sqrt(max(res, 0.0)), 1.0);
}
#endif