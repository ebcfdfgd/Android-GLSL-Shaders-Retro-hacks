#version 110

/* Blargg Ultra-Lite (Final Precise Build)
   - Fixed: Chroma Bleed and Red Persistence are now fully operational.
   - Fixed: Rainbow transparency and global power independence.
   - Optimization: Clean YIQ to RGB reconstruction.
*/

#pragma parameter ntsc_hue "NTSC Phase Shift" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.1
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
#pragma parameter rb_global_strength "Rainbow Master Power" 1.0 0.0 5.0 0.1
#pragma parameter rb_power "Rainbow Transparency (Mix)" 0.35 0.0 2.0 0.01
#pragma parameter dot_crawl "Dot Crawl Intensity" 0.25 0.0 1.0 0.01
#pragma parameter de_dither "Dither Blending Strength" 0.50 0.0 1.0 0.01
#pragma parameter pi_mod "Subcarrier Phase Angle" 131.5 0.0 360.0 0.1
#pragma parameter vert_scal "Vertical Phase Scale" 0.5 0.0 2.0 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hue_trig; 
uniform mat4 MVPMatrix;
uniform float ntsc_hue;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 hue_trig;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, COL_BLEED, red_persistence, rb_global_strength, rb_power, dot_crawl, de_dither, pi_mod, vert_scal;
#endif

#define PI 3.14159265

void main() {
    vec2 ps = 1.0 / TextureSize;
    float time = float(FrameCount);
    
    // --- 1. FETCH MAIN & SURROUNDINGS ---
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    vec3 col_l = texture2D(Texture, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, vTexCoord + vec2(ps.x, 0.0)).rgb;

    float y_m = dot(col_m, vec3(0.299, 0.587, 0.114));
    float y_l = dot(col_l, vec3(0.299, 0.587, 0.114));
    float y_r = dot(col_r, vec3(0.299, 0.587, 0.114));

    // --- 2. DITHER & RAINBOW DETECTION ---
    float auto_detect = clamp(abs(y_l - y_m) + abs(y_r - y_m) - abs(y_l - y_r), 0.0, 1.0);
    float rb_mask = smoothstep(0.02, 0.15, auto_detect);

    float final_y = (de_dither > 0.0) ? mix(y_m, (y_l * 0.25 + y_m * 0.5 + y_r * 0.25), de_dither * rb_mask) : y_m;

    // --- 3. NTSC PHASE & DOT CRAWL ---
    float x_c = floor(vTexCoord.x * TextureSize.x);
    float y_c = floor(vTexCoord.y * TextureSize.y);
    float phase = (x_c * pi_mod * 0.01745) + (y_c * vert_scal * PI) + (mod(time, 2.0) * PI);
    final_y += sin(phase) * dot_crawl * rb_mask;

    // --- 4. CHROMA & RAINBOW ENGINE ---
    // Extract raw YIQ
    float i = dot(col_m, vec3(0.5957, -0.2744, -0.3212));
    float q = dot(col_m, vec3(0.2114, -0.5227, 0.3113));

    // Inject Rainbow (before bleed for better blending)
    float rb_i = sin(phase) * rb_mask * rb_global_strength;
    float rb_q = cos(phase) * rb_mask * rb_global_strength;
    i = mix(i, i + rb_i, rb_power);
    q = mix(q, q + rb_q, rb_power);

    // --- 5. CHROMA BLEED & RED PERSISTENCE (FIXED) ---
    if (COL_BLEED > 0.0) {
        float bleed_step = ps.x * COL_BLEED;
        vec3 col_bleed_l = texture2D(Texture, vTexCoord - vec2(bleed_step, 0.0)).rgb;
        vec3 col_bleed_r = texture2D(Texture, vTexCoord + vec2(bleed_step, 0.0)).rgb;
        
        float i_l = dot(col_bleed_l, vec3(0.5957, -0.2744, -0.3212));
        float i_r = dot(col_bleed_r, vec3(0.5957, -0.2744, -0.3212));
        float q_l = dot(col_bleed_l, vec3(0.2114, -0.5227, 0.3113));
        float q_r = dot(col_bleed_r, vec3(0.2114, -0.5227, 0.3113));

        // Apply global chroma blur
        i = mix(i, (i_l + i_r) * 0.5, 0.5);
        q = mix(q, (q_l + q_r) * 0.5, 0.5);

        // Apply Red Persistence (Right-side Smear)
        if (red_persistence > 0.0) {
            i = mix(i, i_l, 0.5 * red_persistence);
        }
    }

    // --- 6. HUE SHIFT & FINAL ASSEMBLY ---
    float fI = i * hue_trig.x - q * hue_trig.y;
    float fQ = i * hue_trig.y + q * hue_trig.x;

    vec3 rgb = vec3(
        final_y + 0.9563 * fI + 0.6210 * fQ,
        final_y - 0.2721 * fI - 0.6474 * fQ,
        final_y - 1.1070 * fI + 1.7046 * fQ
    );
    
    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
#endif