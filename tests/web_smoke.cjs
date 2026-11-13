// 任意の追加検証。環境側のPlaywrightとChromiumを使い、ゲームには組み込まない。
const { chromium } = require('playwright');
const fs = require('node:fs');

async function checkpoint(page) {
  return page.evaluate(() => new Promise((resolve, reject) => {
    const request = indexedDB.open('/userfs');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains('FILE_DATA')) { db.close(); resolve(null); return; }
      const transaction = db.transaction('FILE_DATA', 'readonly');
      const cursor = transaction.objectStore('FILE_DATA').openCursor();
      let saved = null;
      cursor.onsuccess = () => {
        const entry = cursor.result;
        if (!entry) return;
        if (String(entry.key).endsWith('/expedition_save.json')) {
          saved = JSON.parse(new TextDecoder().decode(entry.value.contents));
        }
        entry.continue();
      };
      transaction.oncomplete = () => { db.close(); resolve(saved); };
      transaction.onerror = () => reject(transaction.error);
    };
  }));
}

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.YAKUSOU_CHROMIUM || '/usr/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader'],
  });
  try {
    fs.mkdirSync('work/web', { recursive: true });
    const page = await browser.newPage({ viewport: { width: 1100, height: 780 } });
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    await page.goto(process.env.YAKUSOU_WEB_URL || 'http://127.0.0.1:8765');
    await page.waitForFunction(() => !document.querySelector('#status'), {}, { timeout: 60000 });
    await page.waitForTimeout(500);
    await page.screenshot({ path: 'work/web/title.png' });
    await page.keyboard.press('Enter');
    await page.waitForTimeout(200);
    // 最初の応答を順に選ぶ経路はGameFlow実測で40入力。序章→3地点→救出→結末。
    for (let index = 0; index < 40; index++) {
      await page.keyboard.press('Enter');
      await page.waitForTimeout(100);
    }
    await page.waitForTimeout(1000);
    await page.screenshot({ path: 'work/web/ending.png' });
    const saved = await checkpoint(page);
    if (saved?.event !== 'ending' || !saved?.state.rescued || saved?.state.visited.length !== 3) {
      throw new Error('Web版が3地点の探索・救出・結末の保存に到達しなかった: ' + JSON.stringify(saved));
    }
    await page.reload();
    await page.waitForFunction(() => !document.querySelector('#status'), {}, { timeout: 60000 });
    await page.waitForTimeout(500);
    await page.keyboard.press('Enter'); // 有効セーブがある場合の初期フォーカスは「つづきから」。
    await page.waitForTimeout(300);
    await page.screenshot({ path: 'work/web/continued.png' });
    const restored = await checkpoint(page);
    if (JSON.stringify(saved) !== JSON.stringify(restored)) throw new Error('再読込で保存内容が変化した');
    if (errors.length) throw new Error(errors.join('\n'));
    console.log(JSON.stringify({ result: 'PASS', errors, checkpoint: saved.event, rescued: saved.state.rescued, visited: saved.state.visited, persistedAfterReload: true }));
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
