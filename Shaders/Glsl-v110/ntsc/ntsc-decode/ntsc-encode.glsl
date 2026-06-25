#version 110

/* NTSC-PHYSICAL-ENCODE-PASS (LITE - NO SMART PHASE + DOT CRAWL) */

#pragma parameter PHASE_SPEED "Phase Crawl Speed" 0.2 0.0 2.0 0.1
#pragma parameter COL_BLEED "Chroma Bleed Strength" 2.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.08 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 4.5 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.0 -2.0 2.0 0.1
#pragma parameter dot_crawl "Dot Crawl Strength" 0.05 0.0 1.0 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;
void main() {
    vTexCoord = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float PHASE_SPEED, COL_BLEED, rb_power, rb_size, rb_detect, rb_tilt, dot_crawl;
#endif

const mat3 RGB_to_YIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

vec2 triangle_wave(float x) {
    return abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    vec3 yiqM = RGB_to_YIQ * cM;

    float fI = yiqM.y;
    float fQ = yiqM.z;

    float phase_offset = float(FrameCount) * PHASE_SPEED;

    // Physical Chroma Bleed Simulation
    if (COL_BLEED > 0.0) {
        vec2 b_off = ps * COL_BLEED * 1.5; 
        vec3 bcL = RGB_to_YIQ * texture2D(Texture, vTexCoord - b_off).rgb;
        vec3 bcR = RGB_to_YIQ * texture2D(Texture, vTexCoord + b_off).rgb;
        fI = mix(fI, (bcL.y + bcR.y) * 0.5, 0.7);
        fQ = mix(fQ, (bcL.z + bcR.z) * 0.5, 0.7);
    }

    // Physical Rainbow Artifacts
    if (rb_power > 0.0) {
        vec3 cL = RGB_to_YIQ * texture2D(Texture, vTexCoord - ps).rgb;
        vec3 cR = RGB_to_YIQ * texture2D(Texture, vTexCoord + ps).rgb;
        float edge = abs(yiqM.x - cL.x) + abs(yiqM.x - cR.x);
        float mask = smoothstep(rb_detect, rb_detect + 0.1, edge);
        
        float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + phase_offset;
        vec2 wave = triangle_wave(ang);
        
        fI += wave.x * rb_power * mask;
        fQ += wave.y * rb_power * mask;
    }

    // Physical Dot Crawl
    if (dot_crawl > 0.0) {
        float chroma_strength = length(vec2(fI, fQ));
        float crawl_ang = (vTexCoord.x * TextureSize.x * 0.5) + (vTexCoord.y * TextureSize.y * 1.5) - (phase_offset * 4.0);
        float crawl_pattern = triangle_wave(crawl_ang).x;
        yiqM.x += crawl_pattern * dot_crawl * chroma_strength * 0.5;
    }

    // CRITICAL FIX: Scale and bias I and Q channels to [0.0, 1.0] to prevent color crushing
    gl_FragColor = vec4(yiqM.x, fI * 0.5 + 0.5, fQ * 0.5 + 0.5, 1.0);
}
#endif