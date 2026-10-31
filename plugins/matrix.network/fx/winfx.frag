#version 440
// Window open "materialize" (fmode 0): the window rect starts as a solid block of
// scrambling glyphs that dissolves cell by cell, white-hot as each cell decodes.
// Window close "de-rez" (fmode 1): the rect snaps to glyphs, then each column
// drops away under gravity, staggered, fading as it falls.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float prog;
    float fmode;
    float blockH;
    float cell;
    float atlasCols;
    float atlasCount;
    vec2 res;
};
layout(binding = 1) uniform sampler2D atlas;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec4 glyph(vec2 cr, vec2 lu, float bright, float hot) {
    float tick = floor(time * (12.0 + h(cr) * 18.0));
    float idx = floor(h(cr + tick * 0.618) * atlasCount);
    lu.x = 1.0 - lu.x;
    vec2 uv = (vec2(mod(idx, atlasCols), floor(idx / atlasCols)) + lu) / atlasCols;
    float a = texture(atlas, uv).a * bright;
    vec3 col = mix(vec3(0.0, 1.0, 0.255), vec3(0.9, 1.0, 0.93), hot);
    return vec4(col, a);
}

void main() {
    vec2 px = qt_TexCoord0 * res;
    vec3 bg = vec3(0.004, 0.02, 0.008);
    if (fmode > 1.5) {
        // toggle "rescan": an opaque band of glyphs sweeps down the new geometry
        float B = max(48.0, res.y * 0.16);
        float head = prog * (res.y + B);
        float d = head - px.y;
        if (d < 0.0 || d > B) { fragColor = vec4(0.0); return; }
        vec2 cr = floor(px / cell);
        float g = 1.0 - d / B;
        float hot = smoothstep(0.75, 1.0, g);
        vec4 gl = glyph(cr, fract(px / cell), 0.45 + 0.55 * g, hot);
        float bga = smoothstep(0.0, 0.3, g);
        vec3 rgb = mix(bg * bga, gl.rgb, gl.a);
        fragColor = vec4(rgb, max(bga, gl.a)) * qt_Opacity;
        return;
    }
    if (fmode < 0.5) {
        vec2 cr = floor(px / cell);
        // cells resolve top-left to bottom-right with lots of noise
        float order = 0.55 * h(cr) + 0.45 * (px.y / res.y * 0.7 + px.x / res.x * 0.3);
        float t = prog * 1.15 - order;               // >0 once this cell starts decoding
        if (t > 0.18) { fragColor = vec4(0.0); return; }
        float hot = smoothstep(0.0, 0.18, t);        // flare white just before vanishing
        vec4 g = glyph(cr, fract(px / cell), 0.6 + 0.4 * h(cr + 3.0), hot);
        vec3 rgb = mix(bg, g.rgb, g.a);
        fragColor = vec4(rgb, 1.0) * qt_Opacity;
    } else {
        float c = floor(px.x / cell);
        float delay = h(vec2(c, 9.0)) * 0.35;
        float t = max(0.0, prog - delay);
        float fall = t * t * blockH * (2.2 + 1.6 * h(vec2(c, 4.0)));
        float sy = px.y - fall;                      // source y in the original block
        if (sy < 0.0 || sy > blockH) { fragColor = vec4(0.0); return; }
        vec2 cr = vec2(c, floor(sy / cell));
        float fade = 1.0 - smoothstep(0.15, 0.65, t);
        vec4 g = glyph(cr, vec2(fract(px.x / cell), fract(sy / cell)), 0.5 + 0.5 * h(cr), 0.0);
        vec3 rgb = mix(bg, g.rgb, g.a) * fade;
        fragColor = vec4(rgb, fade) * qt_Opacity;
    }
}
