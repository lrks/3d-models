// =========================================================
// ハニカム構造プレート
//
// フレーム内側の境界でハニカム模様を切り抜く方式。
// auto_fit を有効にすると、直径を直接指定する代わりに
// 「指定した方向に何個並べるか」から直径を自動計算し、
// その方向の左右(または上下)の端がちょうど半分の六角形で
// 揃うようにする。
//
// ※ 六角形の幾何学的な制約上、縦横どちらの方向も同時に
//    ぴったり揃えることはできない（式を立てると矛盾する）。
//    そのため fit_axis で優先する方向を1つだけ選ぶ。
//    もう一方の方向は従来通り中央基準でクリップされる。
// =========================================================

// ---- 基本パラメータ ----
plate_length = 210;   // X方向のサイズ [mm]
plate_width  = 99;    // Y方向のサイズ [mm]
thickness    = 2;     // 板の厚さ [mm]

wall_thickness = 1.6;  // ハニカムの壁（穴同士の間隔）[mm]
border         = 3.2;    // 外周の枠として残す幅 [mm]

// ---- 直径の自動フィット設定 ----
auto_fit  = true;   // true: fit_axis 方向にちょうど揃うよう直径を自動計算
                     // false: hex_radius_manual をそのまま使う（従来通り両方向センター基準クリップ）
fit_axis  = "x";     // "x"（横=210mm側） または "y"（縦=97mm側）を優先して揃える
fit_count = 16;      // fit_axis方向に並べる六角形の数（両端の半分の六角形を1個として数える）

hex_radius_manual = 6; // auto_fit = false のときに使う六角形の外接円半径 [mm]

$fn = 6; // 六角形の分割数（変更しない）

// ---- 内側寸法とモード判定 ----
W = plate_length - 2 * border; // フレーム内側の幅
H = plate_width  - 2 * border; // フレーム内側の高さ

effective_axis = auto_fit ? fit_axis : "none";

// hex_radius / dx / dy を決定
hex_radius =
    (effective_axis == "x") ? ((W / fit_count - wall_thickness) / sqrt(3)) :
    (effective_axis == "y") ? ((H / fit_count - wall_thickness * sqrt(3) / 2) / 1.5) :
    hex_radius_manual;

dx = (effective_axis == "x") ? (W / fit_count) : (sqrt(3) * hex_radius + wall_thickness);
dy = (effective_axis == "y") ? (H / fit_count) : (1.5 * hex_radius + wall_thickness * sqrt(3) / 2);

// 直径が負や極端に小さくなっていないか簡易チェック
assert(hex_radius > 0.3,
    "hex_radius が小さすぎます。fit_count を減らすか wall_thickness / border を見直してください。");

// ---- 六角形1個の穴 ----
module hex_hole(r, h) {
    rotate([0, 0, 30])
        cylinder(r = r, h = h, center = true);
}

// ---- フレーム内側の領域でクリップされたハニカム穴群 ----
module honeycomb_holes() {
    x0 = border;
    x1 = plate_length - border;
    y0 = border;
    y1 = plate_width  - border;

    cx = (x0 + x1) / 2;
    cy = (y0 + y1) / 2;

    intersection() {
        union() {
            if (effective_axis == "x") {
                // --- X方向を厳密に揃える：左右の端はちょうど半分の六角形になる ---
                n_rows_pad = ceil((y1 - y0) / (2 * dy)) + 2;
                for (j = [-n_rows_pad : n_rows_pad]) {
                    y = cy + j * dy;
                    phase = (j % 2 == 0) ? 0 : dx / 2;
                    for (i = [-2 : fit_count + 2]) {
                        x = x0 + i * dx + phase;
                        translate([x, y, thickness / 2])
                            hex_hole(hex_radius, thickness + 2);
                    }
                }
            } else if (effective_axis == "y") {
                // --- Y方向を厳密に揃える：上下の端はちょうど半分の六角形になる ---
                n_cols_pad = ceil((x1 - x0) / dx) + 4;
                for (k = [-2 : fit_count + 2]) {
                    y = y0 + k * dy;
                    phase = (k % 2 == 0) ? 0 : dx / 2;
                    for (i = [-n_cols_pad : n_cols_pad]) {
                        x = cx + i * dx + phase;
                        translate([x, y, thickness / 2])
                            hex_hole(hex_radius, thickness + 2);
                    }
                }
            } else {
                // --- 手動モード：両方向とも中央基準で対称にクリップ（従来通り） ---
                n_rows_pad = ceil((y1 - y0) / (2 * dy)) + 2;
                n_cols_pad = ceil((x1 - x0) / dx) + 4;
                for (j = [-n_rows_pad : n_rows_pad]) {
                    y = cy + j * dy;
                    phase = (j % 2 == 0) ? 0 : dx / 2;
                    for (i = [-n_cols_pad : n_cols_pad]) {
                        x = cx + i * dx + phase;
                        translate([x, y, thickness / 2])
                            hex_hole(hex_radius, thickness + 2);
                    }
                }
            }
        }

        // フレーム内側の境界でクリップ
        translate([x0, y0, -1])
            cube([x1 - x0, y1 - y0, thickness + 2]);
    }
}

// ---- ハニカム構造のメインモジュール ----
module honeycomb_plate() {
    difference() {
        cube([plate_length, plate_width, thickness]);
        honeycomb_holes();
    }
}

honeycomb_plate();

// 参考: 実際に使われている六角形半径・ピッチをコンソールに表示
echo(str("hex_radius = ", hex_radius, " mm"));
echo(str("dx = ", dx, " mm,  dy = ", dy, " mm"));
