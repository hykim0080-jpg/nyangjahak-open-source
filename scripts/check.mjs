import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const allowed = new Set([
  '.gitignore', 'LICENSE', 'README.md', 'PRIVACY_POLICY.md', 'TESTING.md',
  'docs/ASSETS_AND_RIGHTS.md', 'docs/RELEASE_CHECKLIST.md', 'docs/VALIDATION.md',
  'scripts/check.mjs', 'tools/render_icon.swift', 'NyangJahak.xcodeproj/project.pbxproj',
  'NyangJahak/CarryLog.swift', 'NyangJahak/NyangJahakApp.swift',
  'NyangJahak/GameStore.swift', 'NyangJahak/BoxScreens.swift',
  'NyangJahak/CarryScreens.swift', 'NyangJahak/Models.swift', 'NyangJahak/Drawing.swift',
  'NyangJahak/Localizable.xcstrings', 'NyangJahak/InfoPlist.xcstrings',
  'NyangJahak/PrivacyInfo.xcprivacy', 'NyangJahak/Assets.xcassets/Contents.json',
  'NyangJahak/Assets.xcassets/AppIcon.appiconset/Contents.json',
  'NyangJahak/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
]);
function inventory(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => {
    const full = path.join(dir, e.name);
    assert(!e.isSymbolicLink(), 'symlinks are not allowed');
    return e.isDirectory() ? inventory(full) : [path.relative(root, full).split(path.sep).join('/')];
  });
}
const files = inventory(root);
const text = p => fs.readFileSync(path.join(root, p), 'utf8');
let checks = 0;
function check(name, run) { run(); checks++; console.log(`PASS ${checks}: ${name}`); }
check('exact reviewed file allowlist', () => assert.deepEqual([...files].sort(), [...allowed].sort()));
check('no original history, store assets, credentials or build paths', () => {
  for (const p of files) assert(!/(^|\/)(\.git|AppStore|DerivedData|build|xcuserdata)(\/|$)|\.(?:p8|p12|pem|key|cer|mobileprovision|ipa|zip)$/i.test(p), 'prohibited path');
});
check('only the reviewed app icon is binary', () => {
  for (const p of files) if (p !== 'NyangJahak/Assets.xcassets/AppIcon.appiconset/AppIcon.png') {
    const b = fs.readFileSync(path.join(root, p));
    assert(!b.includes(0), 'unexpected binary payload');
    assert(b.length < 1000000, 'unexpected large text file');
  }
});
check('configured credential/contact/local-home patterns absent', () => {
  const rules = [
    /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
    /\bgh[pousr]_[A-Za-z0-9]{20,}\b/, /\bgithub_pat_[A-Za-z0-9_]{30,}\b/,
    /\bsk-(?:proj-)?[A-Za-z0-9_-]{24,}\b/,
    /"type"\s*:\s*"service_account"/, /"private_key"\s*:/,
    /\bAIza[A-Za-z0-9_-]{30,}\b/, /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i,
    /\/(?:Users|home)\/[^\s/]+\//
  ];
  for (const p of files) {
    if (p === 'scripts/check.mjs' || p.endsWith('.png')) continue;
    const contents = text(p);
    for (const [i, rule] of rules.entries()) assert(!rule.test(contents), `${p}: sensitive pattern ${i + 1}; value intentionally not displayed`);
  }
});
const project = text('NyangJahak.xcodeproj/project.pbxproj');
check('two empty signing-team settings', () => assert.equal((project.match(/DEVELOPMENT_TEAM = "";/g) || []).length, 2));
check('both bundle IDs are the sample identifier', () => {
  const values = [...project.matchAll(/PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/g)].map(m => m[1]);
  assert.deepEqual(values, ['org.example.meowntum', 'org.example.meowntum']);
});
check('no automatic shell build phases or package references', () => assert(!/PBXShellScriptBuildPhase|XCRemoteSwiftPackageReference|XCSwiftPackageProductDependency/.test(project)));
check('iOS minimum and Swift language mode are retained', () => {
  assert.equal((project.match(/IPHONEOS_DEPLOYMENT_TARGET = 17\.0;/g) || []).length, 2);
  assert.equal((project.match(/SWIFT_VERSION = 5\.0;/g) || []).length, 2);
});
check('Release build blocks do not define DEBUG', () => {
  const blocks = [...project.matchAll(/\w+ \/\* Release \*\/ = \{[\s\S]*?name = Release;/g)];
  assert.equal(blocks.length, 2);
  for (const [block] of blocks) assert(!/SWIFT_ACTIVE_COMPILATION_CONDITIONS[^;]*DEBUG/.test(block));
});
const jsonPaths = files.filter(p => p.endsWith('.json') || p.endsWith('.xcstrings'));
check('JSON/localization catalogs parse', () => { for (const p of jsonPaths) JSON.parse(text(p)); });
check('localization source languages remain Korean', () => {
  for (const p of ['NyangJahak/Localizable.xcstrings', 'NyangJahak/InfoPlist.xcstrings']) assert.equal(JSON.parse(text(p)).sourceLanguage, 'ko');
});
check('icon catalog references an included local file', () => {
  const dir = 'NyangJahak/Assets.xcassets/AppIcon.appiconset/';
  const catalog = JSON.parse(text(dir + 'Contents.json'));
  assert.equal(catalog.images.length, 1);
  assert.equal(catalog.images[0].filename, 'AppIcon.png');
  assert(files.includes(dir + catalog.images[0].filename));
});
check('icon is a 1024px PNG without textual metadata chunks', () => {
  const b = fs.readFileSync(path.join(root, 'NyangJahak/Assets.xcassets/AppIcon.appiconset/AppIcon.png'));
  assert.equal(b.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  assert.equal(b.readUInt32BE(16), 1024); assert.equal(b.readUInt32BE(20), 1024);
  let offset = 8;
  while (offset < b.length) {
    const length = b.readUInt32BE(offset), kind = b.toString('ascii', offset + 4, offset + 8);
    assert(!['tEXt', 'zTXt', 'iTXt', 'eXIf'].includes(kind), 'metadata needs review');
    offset += 12 + length;
  }
  assert.equal(offset, b.length);
});
const swiftFiles = files.filter(p => p.startsWith('NyangJahak/') && p.endsWith('.swift'));
const swift = swiftFiles.map(text).join('\n');
check('seven app source files and Apple-only import names', () => {
  assert.equal(swiftFiles.length, 7);
  const imports = new Set([...swift.matchAll(/^import\s+(\w+)/gm)].map(m => m[1]));
  for (const name of imports) assert(['SwiftUI', 'CoreMotion', 'UIKit', 'Foundation'].includes(name), 'unreviewed import');
});
check('no configured app networking/auth/analytics API names', () => assert(!/\b(?:URLSession|NSURLConnection|WKWebView|NWConnection|FirebaseApp|Analytics|ASAuthorizationController|CKContainer)\b/.test(swift)));
check('local persistence and sensor APIs remain visible', () => {
  assert(/UserDefaults\.standard/.test(swift)); assert(/JSONEncoder/.test(swift)); assert(/JSONDecoder/.test(swift));
  assert(/CMMotionManager/.test(swift)); assert(/isProximityMonitoringEnabled/.test(swift));
});
check('debug controls are conditionally compiled', () => {
  assert(/#if DEBUG/.test(text('NyangJahak/NyangJahakApp.swift')));
  assert(/#if DEBUG/.test(text('NyangJahak/GameStore.swift')));
});
check('privacy manifest declares no tracking and local-settings API reason', () => {
  const manifest = text('NyangJahak/PrivacyInfo.xcprivacy');
  assert(/<key>NSPrivacyTracking<\/key>\s*<false\s*\/>/.test(manifest));
  assert(manifest.includes('NSPrivacyAccessedAPICategoryUserDefaults')); assert(manifest.includes('CA92.1'));
});
check('approved MIT license and validation limits remain explicit', () => {
  assert(text('LICENSE').startsWith('MIT License'));
  assert(text('LICENSE').includes('Permission is hereby granted'));
  assert(text('docs/VALIDATION.md').includes('[blocked] Full build'));
});
console.log(`\n${checks} static checks passed across ${files.length} reviewed files.`);
console.log('Pattern/static checks only. No compile, typecheck, runtime, device or legal clearance is implied.');
