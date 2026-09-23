// Checks footer-status-order.ts against the footer's own transform
// (footer.js: Array.from(map.entries()).sort(([a],[b]) => a.localeCompare(b))).
// Run: node footer-status-order.check.js
import { pinStatusOrder } from "./footer-status-order.ts";

const footerLine = (map) =>
  Array.from(map.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([, text]) => text)
    .join(" ");

const assertLine = (map, want) => {
  const got = footerLine(map);
  if (got !== want) throw new Error(`footer line: got "${got}", want "${want}"`);
};

const all = new Map([["caveman", "C"], ["ponytail", "P"], ["perf", "F"]]);
assertLine(all, "C F P"); // alphabetical before the patch: caveman, perf, ponytail
pinStatusOrder(all);
assertLine(all, "F P C");

const other = new Map([["fabric", "X"], ["caveman", "C"], ["perf", "F"]]);
pinStatusOrder(other);
assertLine(other, "F C X"); // unknown statuses stay alphabetical, after the pinned ones

all.set("ponytail", "P2"); // live updates still flow through
all.delete("perf"); // and so do clears
assertLine(all, "P2 C");

pinStatusOrder(all); // reload path must not wrap the iterator twice
assertLine(all, "P2 C");

// /reload loads the extension module with jiti moduleCache:false, so module scope is
// fresh while the status map survives. A cache-busted import is the same situation.
const afterReload = await import("./footer-status-order.ts?reload=1");
afterReload.pinStatusOrder(all);
assertLine(all, "P2 C");

pinStatusOrder(new Map([["perf", "F"]]), ["perf"]);
console.log("footer-status-order: ok");
