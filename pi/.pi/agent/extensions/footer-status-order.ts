/**
 * Pins the footer status line order to pi-perf, ponytail, caveman.
 *
 * pi joins every extension status onto one footer line sorted alphabetically by
 * the key each extension passes to ctx.ui.setStatus(), so the keys in use
 * ("caveman", "perf", "ponytail") render as caveman, perf, ponytail. pi 0.87.0
 * has no setting for that order.
 *
 * The footer reads the status map as entries and uses the entry key only for
 * sorting and the value only for rendering, so this extension takes over the
 * entry iterator on the live map and re-keys the three statuses into the wanted
 * order. Statuses from any other extension keep their alphabetical order and
 * land after these three.
 *
 * ponytail: reaches into pi internals (setFooter hands out the footer data
 * provider, and the footer sorts by entry key). If either changes, the order
 * quietly reverts and nothing throws. Delete this file once pi grows a status
 * ordering setting.
 */
import type { ExtensionAPI, ReadonlyFooterDataProvider } from "@earendil-works/pi-coding-agent";

export const PINNED_STATUS_ORDER = ["perf", "ponytail", "caveman"];

/** Sort keys for the pinned statuses: index for them, "9"+key for the rest. */
const restKey = (key: string) => `9${key}`;

const patched = new WeakSet<Map<string, string>>();

/** Re-key a status map's entries so a consumer sorting by key sees `order` first. */
export function pinStatusOrder(
  statuses: ReadonlyMap<string, string>,
  order: readonly string[] = PINNED_STATUS_ORDER,
): void {
  const map = statuses as Map<string, string>;
  if (patched.has(map)) return; // a /reload would otherwise wrap the iterator twice
  patched.add(map);

  const realEntries = map.entries.bind(map);
  const pinned = new Set(order);

  map.entries = function* () {
    for (const [index, key] of order.entries()) {
      const text = map.get(key);
      if (text !== undefined) yield [`${index}`, text] as [string, string];
    }
    for (const [key, text] of realEntries()) {
      if (!pinned.has(key)) yield [restKey(key), text] as [string, string];
    }
  } as typeof map.entries;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    try {
      let statuses: ReadonlyMap<string, string> | undefined;
      // setFooter's factory is the only place pi hands out the status map.
      ctx.ui.setFooter((_tui, _theme, footerData: ReadonlyFooterDataProvider) => {
        statuses = footerData.getExtensionStatuses();
        return { render: () => [], invalidate() {} };
      });
      ctx.ui.setFooter(undefined); // hand the built-in footer straight back
      if (statuses) pinStatusOrder(statuses);
    } catch {
      // Status order is cosmetic; never fail a session over it.
    }
  });
}
