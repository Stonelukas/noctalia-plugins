#!/usr/bin/env node
// generate-scheme-cache.js — scans all theme-ctl theme sources and builds SchemeCache.js
// Sources (in priority order — last wins):
//   1. ~/.local/share/omarchy/themes/   (omarchy built-in themes)
//   2. ~/.config/omarchy/themes/        (omarchy user themes)
//   3. ~/.local/share/hyde-themes/      (HyDE community themes)
//   4. ~/dotfiles/themes/               (curated dotfiles themes — highest priority)

const fs = require("fs");
const path = require("path");
const os = require("os");

const ThemePipeline = require("./ThemePipeline.js");
const ColorsConvert = require("./ColorsConvert.js");

function parseColorsToml(content) {
  const colors = {};
  for (const line of content.split("\n")) {
    const t = line.trim();
    if (!t || t.startsWith("#") || t.startsWith("[")) continue;
    const m = t.match(/=\s*["'](?:#|0x)?([a-fA-F0-9]{6,8})["']/);
    if (m) {
      const km = t.match(/^([a-zA-Z0-9_]+)\s*=/);
      if (km) colors[km[1]] = "#" + m[1].toLowerCase().slice(-6);
    }
  }
  if (!colors.background || !colors.foreground) return null;
  return colors;
}

function scanDir(dir, label) {
  const themes = {};
  if (!fs.existsSync(dir)) {
    console.log(`  [skip] ${label}: ${dir}`);
    return themes;
  }
  console.log(`\n[scan] ${label}: ${dir}`);
  for (const entry of fs.readdirSync(dir)) {
    let realPath = path.join(dir, entry);
    try {
      if (fs.lstatSync(realPath).isSymbolicLink()) realPath = fs.realpathSync(realPath);
      if (!fs.statSync(realPath).isDirectory()) continue;
    } catch { continue; }
    const toml = path.join(realPath, "colors.toml");
    if (!fs.existsSync(toml)) { console.log(`  - ${entry} (no colors.toml)`); continue; }
    try {
      const colors = parseColorsToml(fs.readFileSync(toml, "utf8"));
      if (colors) { themes[entry] = colors; console.log(`  ✓ ${entry}`); }
      else console.log(`  ⚠ ${entry} (incomplete colors)`);
    } catch (e) { console.warn(`  ✗ ${entry}: ${e.message}`); }
  }
  return themes;
}

const HOME = os.homedir();
const sources = [
  [path.join(HOME, ".local/share/omarchy/themes"),    "omarchy built-in"],
  [path.join(HOME, ".config/omarchy/themes"),         "omarchy user"],
  [path.join(HOME, ".local/share/hyde-themes"),       "HyDE themes"],
  [path.join(HOME, "dotfiles/themes"),                "dotfiles curated"],
];

console.log("theme-ctl scheme cache generator\n");
let allThemes = {};
for (const [dir, label] of sources) {
  allThemes = { ...allThemes, ...scanDir(dir, label) };
}

const total = Object.keys(allThemes).length;
if (!total) { console.error("\nNo themes found!"); process.exit(1); }
console.log(`\nFound ${total} unique themes. Generating schemes...\n`);

const cache = {};
for (const [name, colors] of Object.entries(allThemes)) {
  process.stdout.write(`  Converting ${name}...`);
  try {
    cache[name] = ThemePipeline.generateScheme(colors, ColorsConvert);
    console.log(" ✓");
  } catch (e) {
    console.log(` ✗ ${e.message}`);
  }
}

const cacheFile = path.join(__dirname, "scheme-cache.json");
fs.writeFileSync(cacheFile, JSON.stringify(cache, null, 2));
console.log(`\n✓ scheme-cache.json written (${Object.keys(cache).length} themes)`);
console.log(`  Run: node update-scheme-cache-embedded.js`);
