#version 440
// Glyph-ring border: a single ring of tiny glyphs along the edge of this item
// (placed just outside the window). Races in from the top-left both ways round,
// then keeps scrambling; dissolves cell by cell when hidden.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float prog;   // 0..1 wave around the perimeter
    float fade;   // 0..1 dissolve
    float cell;
    float atlasCols;
    float atlasCount;
    vec2 res;
    vec4 tint;
    float bright;  // glyph intensity (focused ring > 1)    // ring colour (green idle, orange focused)
    vec4 m0; vec4 m1; vec4 m2; vec4 m3;   // windows stacked above: x y w h (w = 0 unused)
};
layout(binding = 1) uniform sampler2D atlas;

bool inR(vec2 p, vec4 r) { return r.z > 0.0 && p.x >= r.x && p.y >= r.y && p.x < r.x + r.z && p.y < r.y + r.w; }

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 px = qt_TexCoord0 * res;
    if (inR(px, m0) || inR(px, m1) || inR(px, m2) || inR(px, m3)) { fragColor = vec4(0.0); return; }
    float w = res.x, ht = res.y;
    float P = 2.0 * (w + ht);
    float s; vec2 id; vec2 lu;
    if (px.y < cell) {                       // top
        s = px.x; id = vec2(floor(px.x / cell), 0.0);
        lu = vec2(fract(px.x / cell), px.y / cell);
    } else if (px.y > ht - cell) {           // bottom
        s = w + ht + (w - px.x); id = vec2(floor(px.x / cell), 1.0);
        lu = vec2(fract(px.x / cell), (px.y - (ht - cell)) / cell);
    } else if (px.x < cell) {                // left
        s = 2.0 * w + ht + (ht - px.y); id = vec2(floor(px.y / cell), 2.0);
        lu = vec2(px.x / cell, fract(px.y / cell));
    } else if (px.x > w - cell) {            // right
        s = w + px.y; id = vec2(floor(px.y / cell), 3.0);
        lu = vec2((px.x - (w - cell)) / cell, fract(px.y / cell));
    } else { fragColor = vec4(0.0); return; }

    float dist = min(s, P - s);              // from top-left, both directions
    float front = prog * P * 0.5;
    if (dist > front) { fragColor = vec4(0.0); return; }
    if (h(id + 7.3) < fade) { fragColor = vec4(0.0); return; }   // dissolve

    float behind = front - dist;
    float hot = exp(-behind / (cell * 6.0)) * smoothstep(1.0, 0.8, prog);  // white-hot front, gone once settled
    float tick = floor(time * (14.0 + h(id) * 18.0));
    float idx = floor(h(id + tick * 0.618) * atlasCount);
    lu.x = 1.0 - lu.x;
    vec2 uv = (vec2(mod(idx, atlasCols), floor(idx / atlasCols)) + lu) / atlasCols;
    float a = texture(atlas, uv).a * (0.55 + 0.45 * h(id + tick));
    a = min(1.0, a * bright);
    vec3 col = mix(min(tint.rgb * bright + vec3(0.12, 0.0, 0.08) * (bright - 1.0), vec3(1.0)), vec3(1.0, 0.97, 0.9), hot);
    // opaque near-black cell behind each glyph so nothing shows through
    vec3 bg = 0.006 + tint.rgb * 0.03;
    fragColor = vec4(mix(bg, col, a), 1.0) * qt_Opacity;
}
