```glsl
#version 110

#pragma parameter SGPT_BLEND_LEVEL "SGPT Blend Strength" 1.0 0.0 1.0 0.05

// Sin City Tone & Threshold Controls
#pragma parameter SC_BW_THRESHOLD "Black Threshold (Cutoff)" 0.05 0.0 1.0 0.01
#pragma parameter SC_WHITE_THRESHOLD "HUD/White Threshold (Outline Protection)" 0.80 0.0 1.0 0.01

// Outline / Comic Ink Controls
#pragma parameter SC_OUTLINE_STRENGTH "Outline Intensity" 1.5 0.0 4.0 0.1
#pragma parameter SC_OUTLINE_THRESH "Outline Sensitivity" 0.12 0.01 0.50 0.01

// Sin City Accent Color Pass
#pragma parameter SC_ACCENT_ENABLE "Accent Color Pass (0=Off, 1=On)" 1.0 0.0 1.0 1.0
#pragma parameter SC_ACCENT_R "Accent Color Red" 0.95 0.0 1.0 0.01
#pragma parameter SC_ACCENT_G "Accent Color Green" 0.05 0.0 1.0 0.01
#pragma parameter SC_ACCENT_B "Accent Color Blue" 0.05 0.0 1.0 0.01
#pragma parameter SC_ACCENT_TOLERANCE "Accent Color Sensitivity" 0.40 0.05 1.0 0.01

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

uniform float SGPT_BLEND_LEVEL;

uniform float SC_BW_THRESHOLD;
uniform float SC_WHITE_THRESHOLD;

uniform float SC_OUTLINE_STRENGTH;
uniform float SC_OUTLINE_THRESH;

uniform float SC_ACCENT_ENABLE;
uniform float SC_ACCENT_R;
uniform float SC_ACCENT_G;
uniform float SC_ACCENT_B;
uniform float SC_ACCENT_TOLERANCE;

const vec3 Y = vec3(0.299, 0.587, 0.114);

void main()
{
    vec2 dx =
        vec2(
            1.0 / TextureSize.x,
            0.0
        );

    vec2 dy =
        vec2(
            0.0,
            1.0 / TextureSize.y
        );

    // ========================================================
    // 1. Texture Fetches
    // ========================================================

    vec3 C =
        texture2D(
            Texture,
            uv
        ).rgb;

    vec3 L =
        texture2D(
            Texture,
            uv - dx
        ).rgb;

    vec3 R =
        texture2D(
            Texture,
            uv + dx
        ).rgb;

    vec3 U =
        texture2D(
            Texture,
            uv + dy
        ).rgb;

    vec3 D =
        texture2D(
            Texture,
            uv - dy
        ).rgb;

    // ========================================================
    // 2. SGPT Edge-Smoothing
    // ========================================================

    vec3 diffL =
        C - L;

    vec3 diffR =
        C - R;

    float wL =
        dot(
            abs(diffL),
            Y
        );

    float wR =
        dot(
            abs(diffR),
            Y
        );

    vec3 blended_color =
        (
            wR < wL
        )
        ?
        (
            C -
            0.5 *
            SGPT_BLEND_LEVEL *
            diffR
        )
        :
        (
            C -
            0.5 *
            SGPT_BLEND_LEVEL *
            diffL
        );

    blended_color =
        clamp(
            blended_color,
            min(C, min(L, R)),
            max(C, max(L, R))
        );

    // ========================================================
    // 3. Sin City B&W Engine
    // ========================================================

    float lum =
        dot(
            blended_color,
            Y
        );

    float sc_bw =
        smoothstep(
            SC_BW_THRESHOLD,
            SC_WHITE_THRESHOLD,
            lum
        );

    // ========================================================
    // 4. Edge Detection / Comic Ink
    // ========================================================

    vec3 diffU =
        C - U;

    vec3 diffD =
        C - D;

    float edge_mag =
        (
            length(diffL) +
            length(diffR) +
            length(diffU) +
            length(diffD)
        ) * 0.25;

    float is_outline =
        smoothstep(
            SC_OUTLINE_THRESH,
            SC_OUTLINE_THRESH + 0.08,
            edge_mag *
            SC_OUTLINE_STRENGTH
        );

    // ========================================================
    // 5. HUD / White Protection
    // ========================================================

    float hud_protection =
        1.0 -
        smoothstep(
            SC_WHITE_THRESHOLD - 0.05,
            SC_WHITE_THRESHOLD,
            lum
        );

    is_outline *=
        hud_protection;

    sc_bw *=
        1.0 -
        is_outline;

    vec3 base_sincity =
        vec3(
            sc_bw
        );

    // ========================================================
    // 6. Accent Color Pass
    // ========================================================

    if (SC_ACCENT_ENABLE > 0.5)
    {
        vec3 target_color =
            vec3(
                SC_ACCENT_R,
                SC_ACCENT_G,
                SC_ACCENT_B
            );

        float color_len =
            length(
                blended_color
            );

        vec3 norm_pixel =
            (
                color_len > 0.001
            )
            ?
            blended_color / color_len
            :
            vec3(0.0);

        vec3 norm_target =
            normalize(
                target_color
            );

        float dist =
            distance(
                norm_pixel,
                norm_target
            );

        float accent_mask =
            1.0 -
            smoothstep(
                0.0,
                SC_ACCENT_TOLERANCE,
                dist
            );

        // Prevent neutral colors from matching the accent.
        float max_c =
            max(
                blended_color.r,
                max(
                    blended_color.g,
                    blended_color.b
                )
            );

        float min_c =
            min(
                blended_color.r,
                min(
                    blended_color.g,
                    blended_color.b
                )
            );

        float sat =
            max_c -
            min_c;

        accent_mask *=
            smoothstep(
                0.05,
                0.20,
                sat
            );

        // Preserve only the selected original color regions.
        base_sincity =
            mix(
                base_sincity,
                blended_color,
                accent_mask
            );
    }

    // ========================================================
    // 7. Final Output
    // No SC_MIX
    // ========================================================

    gl_FragColor =
        vec4(
            clamp(
                base_sincity,
                0.0,
                1.0
            ),
            1.0
        );
}

#endif