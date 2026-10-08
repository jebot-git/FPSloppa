#!/usr/bin/env node
// Use PLAYWRIGHT_MODULE and CHROMIUM_BIN if these packages live outside normal paths.
import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const dir=path.join(root,'docs/manual');
const qa=process.env.MANUAL_QA_DIR||'/tmp/fpsloppa-manual-qa';
await fs.mkdir(qa,{recursive:true});
const browser=await chromium.launch({executablePath:process.env.CHROMIUM_BIN||undefined,headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
try{
 const page=await browser.newPage({viewport:{width:1440,height:1050},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(pathToFileURL(path.join(dir,'index.html')).href);
 await page.locator('img').evaluateAll(imgs=>imgs.forEach(img=>img.loading='eager'));
 await page.evaluate(()=>Promise.all([...document.images].map(img=>img.decode())));
 await page.screenshot({path:path.join(qa,'desktop.png')});
 const structure=await page.evaluate(()=>{
  const ids=[...document.querySelectorAll('[id]')].map(x=>x.id);
  return {chapters:document.querySelectorAll('.chapter').length,words:document.querySelector('main').innerText.split(/\s+/).length,
  duplicateIds:ids.filter((id,i)=>ids.indexOf(id)!==i),brokenAnchors:[...document.querySelectorAll('a[href^="#"]')].filter(a=>!document.getElementById(a.hash.slice(1))).map(a=>a.hash),images:[...document.images].map(i=>({src:i.getAttribute('src'),ok:i.complete&&i.naturalWidth>0})),overflow:document.documentElement.scrollWidth>innerWidth};
 });
 await page.locator('#search').fill('defuse');
 const searchCount=await page.locator('.sidebar nav a:visible').count();
 if(searchCount<1||searchCount>=15)throw Error('Chapter search did not filter');
 await page.locator('#search').fill('this-term-cannot-match-643893');
 if(await page.locator('.sidebar nav a:visible').count()!==0)throw Error('No-results search failed');
 await page.locator('#search').fill('');
 await page.locator('[data-control="desktop"]').click();
 if(await page.locator('[data-device="vr"]').isVisible())throw Error('VR panel did not hide');
 await page.locator('[data-control="all"]').click();
 await page.locator('#reload').scrollIntoViewIfNeeded();
 await page.screenshot({path:path.join(qa,'reload-desktop.png')});
 for(const id of ['launcher','vehicles','music']){
  await page.locator('#'+id).scrollIntoViewIfNeeded();
  await page.screenshot({path:path.join(qa,id+'-desktop.png')});
 }
 await page.setViewportSize({width:390,height:844});
 await page.evaluate(()=>scrollTo(0,0));
 await page.screenshot({path:path.join(qa,'mobile.png')});
 const mobileOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
 await page.locator('.nav-toggle').click();
 if(!await page.locator('.sidebar').isVisible())throw Error('Mobile navigation failed');
 await page.locator('.sidebar a[href="#weapons"]').click();
 if(await page.locator('.sidebar').isVisible())throw Error('Mobile navigation did not close');
 await page.screenshot({path:path.join(qa,'mobile-weapons.png')});
 await page.setViewportSize({width:1440,height:1050});
 await page.emulateMedia({media:'print'});
 // The PDF carries internal chapter links and remote source links. Local-only links
 // remain useful in HTML but would become machine-specific file URIs in a PDF.
 await page.locator('.local-ref').evaluateAll(links=>links.forEach(a=>{if(a.previousSibling?.nodeType===3)a.previousSibling.remove();a.remove();}));
 await page.locator('a.image-link').evaluateAll(links=>links.forEach(a=>a.replaceWith(...a.childNodes)));
 await page.locator('a[href="assets/manifest.json"]').evaluateAll(links=>links.forEach(a=>a.replaceWith(document.createTextNode(a.textContent))));
 await page.pdf({path:path.join(dir,'FPSloppa-Player-Manual.pdf'),format:'A4',printBackground:true,preferCSSPageSize:true,displayHeaderFooter:true,headerTemplate:'<span></span>',footerTemplate:'<div style="font-family:Arial;font-size:8px;color:#54636b;width:100%;margin:0 15mm;display:flex;justify-content:space-between"><span>FPSloppa / PLAYER FIELD MANUAL / 8 OCT 2026</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>',tagged:true,outline:true});
 const result={...structure,mobileOverflow,searchCount,errors};
 await fs.writeFile(path.join(qa,'browser-checks.json'),JSON.stringify(result,null,2));
 console.log(JSON.stringify(result,null,2));
 if(structure.duplicateIds.length||structure.brokenAnchors.length||structure.images.some(i=>!i.ok)||structure.overflow||mobileOverflow||errors.length)throw Error('Manual validation failed');
}finally{await browser.close();}
