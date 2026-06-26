// --- Ultimate Sonic 2026: Master Feature Control ---
#pragma parameter DepthBoost "1. Depth: Boost" 2.2 0.0 5.0 0.1
#pragma parameter DepthSeparation "2. Depth: Separation" 1.2 0.0 5.0 0.1
#pragma parameter HeightBoost "3. Depth: Height Boost" 1.4 0.0 5.0 0.1
#pragma parameter CurvatureBoost "4. Depth: Curvature" 1.6 0.0 5.0 0.1
#pragma parameter AOStrength "5. AO: Strength" 1.0 0.0 2.0 0.1
#pragma parameter LargeAO "6. AO: Large Scale" 0.8 0.0 2.0 0.1
#pragma parameter CavityAO "7. AO: Cavity" 1.4 0.0 3.0 0.1
#pragma parameter AOContrast "8. AO: Contrast" 1.2 0.0 2.0 0.1
#pragma parameter WrapLighting "9. Light: Wrap" 1.1 0.0 2.0 0.1
#pragma parameter RimStrength "10. Light: Rim" 0.9 0.0 2.0 0.1
#pragma parameter FresnelStrength "11. Light: Fresnel" 0.8 0.0 2.0 0.1
#pragma parameter BounceLight "12. Light: Bounce" 0.5 0.0 2.0 0.1
#pragma parameter AmbientLift "13. Light: Amb Lift" 0.15 0.0 1.0 0.05
#pragma parameter SpecularStrength "14. Spec: Strength" 0.7 0.0 2.0 0.1
#pragma parameter SpecularPower "15. Spec: Power" 18.0 1.0 50.0 1.0
#pragma parameter MaterialBoost "16. Spec: Material" 0.6 0.0 2.0 0.1
#pragma parameter EdgeAccent "17. Edge: Accent" 0.4 0.0 2.0 0.1
#pragma parameter EdgeGlow "18. Edge: Glow" 0.2 0.0 2.0 0.1
#pragma parameter DetailBoost "19. Edge: Detail" 0.5 0.0 2.0 0.1
#pragma parameter GIStrength "20. GI: Strength" 0.5 0.0 2.0 0.1
#pragma parameter ColorBleeding "21. GI: Bleed" 0.2 0.0 2.0 0.1
#pragma parameter AtmosphereDepth "22. GI: Atmos Depth" 0.3 0.0 2.0 0.1
#pragma parameter Saturation "23. Color: Saturation" 1.10 0.0 2.0 0.05
#pragma parameter Vibrance "24. Color: Vibrance" 1.20 0.0 2.0 0.05
#pragma parameter Contrast "25. Color: Contrast" 1.15 0.0 2.0 0.05
#pragma parameter LocalContrast "26. Color: Local Cont" 1.25 0.0 2.0 0.05
#pragma parameter HighlightRecovery "27. Tone: Hi Rec" 0.3 0.0 1.0 0.05
#pragma parameter ShadowCompression "28. Tone: Shad Comp" 0.15 0.0 1.0 0.05
#pragma parameter FilmicStrength "29. Tone: Filmic Str" 0.7 0.0 2.0 0.05
#pragma parameter ToneMapping "30. Tone: Mapping" 1.0 0.0 2.0 0.1
#pragma parameter Sharpness "31. Final: Sharpness" 0.2 0.0 2.0 0.1
#pragma parameter Softness "32. Final: Softness" 0.35 0.0 2.0 0.05
#pragma parameter AnalogResponse "33. Final: Analog Resp" 0.8 0.0 2.0 0.05

#version 110

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec2 TexCoord; varying vec2 uv; uniform mat4 MVPMatrix;
void main() { uv = TexCoord; gl_Position = MVPMatrix * VertexCoord; }

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif
varying vec2 uv; uniform sampler2D Texture; uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float DepthBoost, DepthSeparation, HeightBoost, CurvatureBoost, AOStrength, LargeAO, CavityAO, AOContrast, WrapLighting, RimStrength, FresnelStrength, BounceLight, AmbientLift, SpecularStrength, SpecularPower, MaterialBoost, EdgeAccent, EdgeGlow, DetailBoost, GIStrength, ColorBleeding, AtmosphereDepth, Saturation, Vibrance, Contrast, LocalContrast, HighlightRecovery, ShadowCompression, FilmicStrength, ToneMapping, Sharpness, Softness, AnalogResponse;
#endif

float Lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 px = (1.0 / TextureSize) * DepthSeparation;
    vec3 C = texture2D(Texture, uv).rgb;
    
    vec3 L = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb;
    vec3 R = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;
    vec3 U = texture2D(Texture, uv - vec2(0.0, px.y)).rgb;
    vec3 D = texture2D(Texture, uv + vec2(0.0, px.y)).rgb;
    
    float c = Lum(C);
    float l = Lum(L); float r = Lum(R); float u = Lum(U); float d = Lum(D);

    // --- Depth & Normal ---
    vec3 N = normalize(vec3((l - r) * DepthBoost * HeightBoost, (u - d) * DepthBoost * HeightBoost, 1.0));
    float curvature = (abs(l - r) + abs(u - d)) * CurvatureBoost;
    
    // --- AO ---
    float localAvg = (l + r + u + d) * 0.25;
    float AO = 1.0 - clamp(abs(localAvg - c) * AOContrast * AOStrength, 0.0, 1.0);
    AO *= (1.0 - clamp((localAvg - c) * CavityAO, 0.0, 1.0));
    AO = mix(AO, 1.0, 1.0 - LargeAO);
    
    // --- Lighting ---
    float diffuse = max(dot(N, normalize(vec3(-0.4, -0.5, 1.0))), 0.0);
    float invN = 1.0 - max(N.z, 0.0);
    
    float rim = (invN * invN * invN) * RimStrength;
    float fresnel = (invN * invN * invN * invN) * FresnelStrength;
    
    // --- GI & Bounce ---
    vec3 gi = (C * GIStrength) + (vec3(l, c, r) * ColorBleeding);
    
    // --- Composition ---
    vec3 color = C;
    color *= mix(1.0 - AmbientLift, WrapLighting, diffuse);
    color *= AO;
    color += (gi * BounceLight);
    color += (rim * 0.25) + (fresnel * 0.15);
    
    float spec = diffuse * diffuse * diffuse * diffuse;
    color += spec * SpecularStrength * MaterialBoost * (SpecularPower / 20.0);
    
    color += (curvature * EdgeAccent * DetailBoost);
    color += (curvature * EdgeGlow);
    
    // --- Atmosphere ---
    color = mix(color, vec3(0.5), c * AtmosphereDepth);

    // --- Color & Tone ---
    float gray = Lum(color);
    color = mix(vec3(gray), color, Saturation);
    color = mix(color, color * 1.2, Vibrance - 1.0);
    color = (color - 0.5) * Contrast + 0.5;
    color = mix(vec3(gray), color, LocalContrast);
    
    // Final Tone Mapping
    color = mix(color, color / (1.0 + color), ToneMapping);
    color /= (1.0 + color * HighlightRecovery * FilmicStrength);
    color = pow(color, vec3(1.0 + ShadowCompression));
    
    // Sharpness/Softness
    vec3 blurred = (C + L + R + U + D) * 0.2;
    color = mix(color, blurred, Softness);
    color = color + (color - blurred) * Sharpness;
    
    // Analog Response
    color = pow(color, vec3(1.0 / AnalogResponse));
    
    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
#endif