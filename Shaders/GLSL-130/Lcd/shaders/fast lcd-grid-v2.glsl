#version 130

/* FAST-LCD-FINAL-V2 (FIXED LOADING)
   - Same Math & Brush.
   - Clean Structure for Mali GPU.
*/

#pragma parameter RSUBPIX_R  "Red Sub: R" 1.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_G  "Green Sub: G" 1.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_B  "Blue Sub: B" 1.0 0.0 1.0 0.01
#pragma parameter gain       "Gain" 1.0 0.5 2.0 0.05
#pragma parameter gamma      "LCD Input Gamma" 3.0 0.5 5.0 0.1
#pragma parameter outgamma   "LCD Output Gamma" 2.2 0.5 5.0 0.1
#pragma parameter blacklevel "Black level" 0.05 0.0 0.5 0.01
#pragma parameter BGR        "BGR Mode" 0 0 1 1

#if defined(VERTEX)
in vec4 VertexCoord, TexCoord;
out vec2 vTexCoord;
uniform mat4 MVPMatrix;
void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
precision highp float;
in vec2 vTexCoord;
out vec4 FragColor;
uniform sampler2D Texture;
uniform vec2 TextureSize, OutputSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float RSUBPIX_R, GSUBPIX_G, BSUBPIX_B, gain, gamma, outgamma, blacklevel, BGR;
#endif

// دالة التنعيم (الفرشاة)
vec3 S(vec3 x, float dx, float d) {
    vec3 h = clamp((x + dx * 0.5) / d, -1.0, 1.0);
    vec3 l = clamp((x - dx * 0.5) / d, -1.0, 1.0);
    return d * (h * (1.0 - 0.333 * h * h) - l * (1.0 - 0.333 * l * l)) / dx;
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    vec2 rg = InputSize / (OutputSize * TextureSize);
    ivec2 t = ivec2(floor(vTexCoord / ps - 0.5));

    // فك التداخل لضمان التحميل على A20
    vec3 g = vec3(gamma);
    vec3 c00 = pow(max(gain * texelFetch(Texture, t, 0).rgb + blacklevel, 0.0), g);
    vec3 c10 = pow(max(gain * texelFetch(Texture, t + ivec2(1, 0), 0).rgb + blacklevel, 0.0), g);
    vec3 c01 = pow(max(gain * texelFetch(Texture, t + ivec2(0, 1), 0).rgb + blacklevel, 0.0), g);
    vec3 c11 = pow(max(gain * texelFetch(Texture, t + ivec2(1, 1), 0).rgb + blacklevel, 0.0), g);

    float sx = (vTexCoord.x / ps.x - 0.5 - float(t.x)) * 3.0;
    float rx = rg.x / ps.x * 3.0;
    float sy = (vTexCoord.y / ps.y - 0.5 - float(t.y));
    float ry = rg.y / ps.y;

    vec3 lc = S(vec3(sx + 1.0, sx, sx - 1.0), rx, 1.5);
    vec3 rc = S(vec3(sx - 2.0, sx - 3.0, sx - 4.0), rx, 1.5);
    
    if (BGR > 0.5) {
        lc = lc.bgr;
        rc = rc.bgr;
    }

    float tw = S(vec3(sy), ry, 0.63).x;
    float bw = S(vec3(sy - 1.0), ry, 0.63).x;

    // الحساب النهائي الصافي
    vec3 res = (c00 * lc * tw) + (c10 * rc * tw) + (c01 * lc * bw) + (c11 * rc * bw);
    FragColor = vec4(pow(max(res, 0.0), vec3(1.0 / outgamma)), 1.0);
}
#endif