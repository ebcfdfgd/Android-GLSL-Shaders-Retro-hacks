#version 110

/* ULTIMATE-GBA-LCD-HYBRID (Combined 7000 + LCD Accuracy)
   - Layer 1: GBA Reality Remnant (Ghosting, Grain, Profile)
   - Layer 2: LCD Subpixel & Grid Accuracy
*/

// --- ALL PARAMETERS ---
#pragma parameter GBA_PROFILE "GBA: Profile [0:Raw 1:mGBA 2:GBC 3:SP 4:GG 5:DMG 6:101]" 1.0 0.0 6.0 1.0
#pragma parameter GBA_GRAIN "GBA: Plastic Grain Strength" 0.15 0.0 0.50 0.05
#pragma parameter GBA_GHOST "GBA: LCD Ghosting Power" 0.55 0.0 1.0 0.05
#pragma parameter GBA_SPREAD "GBA: Motion Blur Width" 0.7 0.0 2.0 0.05
#pragma parameter GBA_LAG "GBA: Response Lag Jitter" 0.4 0.0 1.5 0.05
#pragma parameter GBA_BLACK "GBA: Black Level (Lift)" 0.02 0.0 0.20 0.01
#pragma parameter GBA_SAT "GBA: Color Saturation" 1.1 0.0 2.0 0.05
#pragma parameter GBA_CON "GBA: Image Contrast" 1.15 0.5 2.0 0.05
#pragma parameter GBA_GAM "GBA: Gamma Correction" 1.10 0.5 3.0 0.05
#pragma parameter GBA_LUM "GBA: Final Brightness" 1.1 0.5 2.0 0.05
#pragma parameter GBA_SOFT "GBA: Edge Softening (AA)" 0.3 0.0 1.0 0.05
#pragma parameter GRID_WIDTH "LCD Grid Width (Vertical)" 0.4 0.0 1.0 0.05
#pragma parameter GRID_HEIGHT "LCD Grid Height (Horizontal)" 0.4 0.0 1.0 0.05
#pragma parameter SUBPIX_STR "Subpixel Strength" 0.6 0.0 1.0 0.05
#pragma parameter BRIGHTNESS_LCD "LCD Brightness" 1.1 1.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTexCoord;
varying vec2 pix_coord;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
    pix_coord = vTexCoord * TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
varying vec2 pix_coord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform float FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float GBA_PROFILE, GBA_GRAIN, GBA_GHOST, GBA_SPREAD, GBA_LAG;
uniform float GBA_BLACK, GBA_SAT, GBA_LUM, GBA_SOFT, GBA_CON, GBA_GAM;
uniform float GRID_WIDTH, GRID_HEIGHT, SUBPIX_STR, BRIGHTNESS_LCD;
#endif

float pseudo_noise(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    vec3 col = texture2D(Texture, vTexCoord).rgb;

    // --- [LAYER 1: GBA EFFECTS] ---
    if (GBA_GHOST > 0.01) {
        float toggle = (mod(FrameCount, 2.0) > 0.5) ? 1.0 : -1.0;
        float off = (GBA_SPREAD + (GBA_LAG * toggle)) * 0.7;
        vec3 s1 = texture2D(Texture, vTexCoord + (ps * off)).rgb;
        vec3 s2 = texture2D(Texture, vTexCoord - (ps * off)).rgb;
        col = mix(col, (s1 + s2) * 0.5, GBA_GHOST * 0.65);
    }

    vec3 res_p = col;
    if (GBA_PROFILE > 0.5) {
        if (GBA_PROFILE < 1.5)      res_p = vec3(dot(col, vec3(0.82, 0.12, 0.01)), dot(col, vec3(0.08, 0.81, 0.08)), dot(col, vec3(0.02, 0.07, 0.91)));
        else if (GBA_PROFILE < 2.5) res_p = vec3(dot(col, vec3(0.70, 0.20, 0.10)), dot(col, vec3(0.15, 0.70, 0.15)), dot(col, vec3(0.15, 0.10, 0.75)));
        else if (GBA_PROFILE < 3.5) { res_p = vec3(dot(col, vec3(0.75, 0.15, 0.10)), dot(col, vec3(0.10, 0.75, 0.15)), dot(col, vec3(0.15, 0.20, 0.65))); res_p.b += 0.05; }
        else if (GBA_PROFILE < 4.5) { res_p = vec3(dot(col, vec3(0.85, 0.10, 0.05)), dot(col, vec3(0.10, 0.85, 0.10)), dot(col, vec3(0.05, 0.10, 0.85))); res_p += 0.03; }
        else if (GBA_PROFILE < 5.5) { res_p = mix(vec3(0.05, 0.1, 0.05), vec3(0.60, 0.75, 0.1), dot(col, vec3(0.299, 0.587, 0.114))); }
        else { res_p = vec3(dot(col, vec3(0.88, 0.08, 0.04)), dot(col, vec3(0.06, 0.88, 0.06)), dot(col, vec3(0.04, 0.08, 0.92))); }
        col = res_p;
    }

    float noise_val = pseudo_noise(vTexCoord * TextureSize);
    col = mix(col, col * (0.9 + 0.2 * noise_val), GBA_GRAIN);
    col = max(col, 0.0) * (1.0 - GBA_BLACK) + GBA_BLACK;
    col = pow(max(col, 0.0), vec3(GBA_GAM));
    col = (col - 0.5) * GBA_CON + 0.5;
    col = mix(vec3(dot(col, vec3(0.21, 0.72, 0.07))), col, GBA_SAT) * GBA_LUM;

    if (GBA_SOFT > 0.01) {
        vec3 sN = (texture2D(Texture, vTexCoord - ps * vec2(1.0, 0.0)).rgb + texture2D(Texture, vTexCoord + ps * vec2(1.0, 0.0)).rgb) * 0.5;
        col = mix(col, sN, GBA_SOFT * 0.5);
    }

    // --- [LAYER 2: LCD ACCURACY] ---
    vec2 subpix_pos = fract(pix_coord);
    float grid_x = smoothstep(0.5 - GRID_WIDTH * 0.5, 0.5 + GRID_WIDTH * 0.5, abs(subpix_pos.x - 0.5));
    float grid_y = smoothstep(0.5 - GRID_HEIGHT * 0.5, 0.5 + GRID_HEIGHT * 0.5, abs(subpix_pos.y - 0.5));
    float mask = 1.0 - max(grid_x, grid_y);

    float x_offset = subpix_pos.x * 3.0;
    vec3 weights;
    weights.r = clamp(1.0 - abs(x_offset - 0.5), 0.0, 1.0);
    weights.g = clamp(1.0 - abs(x_offset - 1.5), 0.0, 1.0) * 0.88;
    weights.b = clamp(1.0 - abs(x_offset - 2.5), 0.0, 1.0) * 1.05;
    vec3 subpixel = mix(vec3(1.0), weights * 1.5, SUBPIX_STR);

    col *= mask;
    col *= subpixel;
    col *= BRIGHTNESS_LCD;

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif