#!/usr/bin/env node
// Strips a single trailing newline from Salesforce metadata source files so
// they match the server's storage format. Salesforce strips trailing newlines
// on store, causing source-tracking to perma-flag files written by prettier.
// Run after `prettier --write` (see the `prettier` npm script).

const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "force-app");
const EXTS = new Set([
    ".cls",
    ".trigger",
    ".page",
    ".component",
    ".cmp",
    ".xml",
    ".json",
    ".js",
    ".html",
    ".css"
]);

let changed = 0;
function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            walk(p);
            continue;
        }
        if (!EXTS.has(path.extname(entry.name))) continue;
        const buf = fs.readFileSync(p);
        if (buf.length === 0) continue;
        if (buf[buf.length - 1] !== 0x0a) continue;
        let end = buf.length - 1;
        if (end > 0 && buf[end - 1] === 0x0d) end -= 1; // \r\n
        fs.writeFileSync(p, buf.subarray(0, end));
        changed++;
    }
}

walk(ROOT);
console.log(`stripped trailing newline from ${changed} files`);
