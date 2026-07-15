// Captures real Beatter screenshots from the running web app (local mode).
//
// Prerequisites:
//   flutter run -d web-server --web-port 8348 --dart-define=FORCE_LOCAL_BACKEND=true
//   (or the `beatter-web-local` config in .claude/launch.json)
//
// Usage:
//   node capture_real_screens.js [phone|tablet|explore] [outDir]
//
// phone  → 430x932 @3x  (1290x2796 PNGs)  → marketing/screenshots/phones
// tablet → 1024x1366 @2x (2048x2732 PNGs) → marketing/screenshots/tablets
// explore → prints the semantic button tree of each screen (for maintenance)

const { chromium } = require('playwright-core');
const path = require('path');

const MODE = process.argv[2] || 'phone';
const OUT = process.argv[3] || path.join(__dirname, '..', 'screenshots',
  MODE === 'tablet' ? 'tablets' : 'phones');
const URL = 'http://localhost:8348';

const VIEWPORTS = {
  phone: { width: 430, height: 932, dpr: 3, mobile: true },
  tablet: { width: 1024, height: 1366, dpr: 2, mobile: false },
  explore: { width: 430, height: 932, dpr: 1, mobile: true },
};

async function main() {
  const vp = VIEWPORTS[MODE] || VIEWPORTS.phone;
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const ctx = await browser.newContext({
    viewport: { width: vp.width, height: vp.height },
    deviceScaleFactor: vp.dpr,
    isMobile: vp.mobile,
    hasTouch: vp.mobile,
  });
  const page = await ctx.newPage();
  await page.goto(URL, { waitUntil: 'networkidle' });
  await page.waitForTimeout(7000); // canvaskit + splash

  // Turn on Flutter's semantics DOM so the canvas app is driveable via ARIA.
  // Retry until the login inputs (or an already-authenticated home) show up.
  for (let i = 0; i < 20; i++) {
    await page.evaluate(() => {
      const el = document.querySelector('flt-semantics-placeholder');
      if (el) el.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });
    await page.waitForTimeout(2000);
    const ready = await page.evaluate(() =>
      document.querySelectorAll('input, [role="button"]').length > 0);
    if (ready) break;
  }

  const shot = async (name) => {
    await page.screenshot({ path: path.join(OUT, name + '.png') });
    console.log('SHOT', name);
  };
  const click = async (label, nth = 0) => {
    await page
      .locator(`[aria-label*="${label}"], [role="button"]:has-text("${label}"), [role="tab"]:has-text("${label}")`)
      .nth(nth).click({ timeout: 10000, force: true });
    await page.waitForTimeout(1500);
    console.log('CLICK', label);
  };
  const tryClick = async (label, nth = 0) => {
    try { await click(label, nth); return true; } catch { return false; }
  };
  const buttons = async () => page.evaluate(() =>
    [...document.querySelectorAll('[role="button"],[role="tab"],[role="slider"],[role="checkbox"]')]
      .map((el, i) => {
        const r = el.getBoundingClientRect();
        return `${i}: [${el.getAttribute('role')}] "${(el.getAttribute('aria-label') || el.textContent).trim().slice(0, 60).replace(/\n/g, ' / ')}" @${Math.round(r.x)},${Math.round(r.y)} ${Math.round(r.width)}x${Math.round(r.height)}`;
      }).join('\n'));

  // Navigate between modes: phones have a drawer behind the "Menu" hamburger,
  // tablets show a permanent navigation rail (no Menu button) — try both.
  const goTo = async (dest) => {
    const drawer = page.locator('[aria-label="Menu"]'); // phone hamburger only
    if (await drawer.count()) {
      await drawer.first().click({ force: true });
      await page.waitForTimeout(800);
    }
    await click(dest);
    await page.waitForTimeout(2000);
  };

  // ---- login (local mode: any well-formed email works) ----
  await page.locator('input').first().waitFor({ timeout: 60000 });
  await page.locator('input').first().click({ force: true });
  await page.keyboard.type('musicista@beatter.com', { delay: 20 });
  await page.locator('input').nth(1).click({ force: true });
  await page.keyboard.type('Ritmo2026!', { delay: 20 });
  await click('ACCEDI ORA');
  await page.waitForTimeout(4500);

  if (MODE === 'explore') {
    console.log('=== HOME ===\n' + (await buttons()));
    await click('Menu');
    await page.waitForTimeout(800);
    console.log('=== DRAWER ===\n' + (await buttons()));
    await browser.close();
    return;
  }

  await shot('home');

  // ---- Flow Mode: generate a rhythm so the staff is populated ----
  await click('Flow Mode');
  await page.waitForTimeout(2000);
  await tryClick('Generate');
  await page.waitForTimeout(2500);
  await shot('flow_mode');

  // ---- Polyrhythm Lab ----
  await goTo('Polyrhythm Lab');
  await shot('polyrhythm_lab');

  // ---- Sheet Mode: pick Medium, capture the generator, then generate ----
  await goTo('Sheet Mode');
  await tryClick('Medium');
  await shot('sheet_generator');
  await tryClick('Genera Esercizio');
  await page.waitForTimeout(3000);
  await shot('sheet_mode');

  // Save it (Reading Mode replays saved exercises), then leave the viewer.
  console.log('VIEWER BUTTONS:\n' + (await buttons()));
  await tryClick('Salva');
  await page.waitForTimeout(1200);
  console.log('AFTER-SALVA BUTTONS:\n' + (await buttons()));
  // A confirm dialog may ask for a title; accept the default.
  await tryClick('SALVA') || await tryClick('Salva', 1) || await tryClick('Conferma');
  await page.waitForTimeout(1200);
  await tryClick('Back');
  await page.waitForTimeout(1500);

  // ---- Reading Mode: open the saved exercise so the player UI shows ----
  await goTo('Reading Mode');
  console.log('READING BUTTONS:\n' + (await buttons()));
  await tryClick('Esercizio') || await tryClick('Lettura') || await tryClick('Nuovo');
  await page.waitForTimeout(2500);
  await shot('reading_mode');
  // Start playback: after the first measure the echo phase shows the tap
  // guide and live score — the shot that actually sells Reading Mode.
  const playBtn = await page.evaluate(() => {
    const cands = [...document.querySelectorAll('[role="button"]')]
      .filter((el) => !(el.getAttribute('aria-label') || el.textContent).trim())
      .map((el) => el.getBoundingClientRect())
      .filter((r) => r.width >= 48 && r.height >= 48);
    cands.sort((a, b) => (b.width * b.height) - (a.width * a.height));
    return cands[0] ? { x: cands[0].x + cands[0].width / 2, y: cands[0].y + cands[0].height / 2 } : null;
  });
  if (playBtn) {
    await page.mouse.click(playBtn.x, playBtn.y);
    await page.waitForTimeout(4200); // ~1 measure at 80 BPM, into the echo window
    await shot('reading_mode_playing');
    await page.mouse.click(playBtn.x, playBtn.y); // stop
    await page.waitForTimeout(800);
  }
  await tryClick('Back');
  await page.waitForTimeout(1500);

  // NOTE: Composer Mode is flagged "Presto" (coming soon) in the current
  // build and cannot be opened — deliberately not captured/advertised.

  await goTo('Home');
  await browser.close();
  console.log('DONE →', OUT);
}

main().catch((e) => { console.error(e); process.exit(1); });
