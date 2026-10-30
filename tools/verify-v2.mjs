import {readFile, writeFile, readdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [luau = 'luau', compiler = 'luau-compile'] = process.argv.slice(2);
const run = (command, args) => execFileSync(command, args, {cwd:root, encoding:'utf8', windowsHide:true});
const build = path.join(root, 'tools', 'build-v2.mjs');
console.log(run(process.execPath, [build]).trim());
const bundlePath = path.join(root, 'dist', 'VW-MENU.lua');
const before = await readFile(bundlePath);
run(process.execPath, [build]);
assert.deepEqual(await readFile(bundlePath), before, 'O build deve ser determinístico');
const sources = (await readdir(path.join(root, 'src', 'v2'))).filter(p=>p.endsWith('.lua')).map(p=>'src/v2/'+p);
const tests = ['tests/core.spec.luau', 'tests/controllers.spec.luau'];
const compilePaths = [...sources, 'dist/VW-MENU.lua', 'loader.lua', ...tests, 'tests/signal.luau'];
const compileOutput = [];
for (const file of compilePaths) compileOutput.push({file, output:run(compiler, ['--null', file]).trim()});
const suites = [];
for (const file of tests) {
  const output = run(luau, [file]);
  console.log(output.trim());
  suites.push({file, passed:output.split(/\r?\n/).filter(line=>line.startsWith('PASS ')).length, output});
}
const result = {
  date:'2026-10-30', environment:'Luau CLI local; sem Roblox Studio ou renderização',
  deterministicBuild:true, compiledFiles:compilePaths.length,
  passedTests:suites.reduce((n,s)=>n+s.passed,0),
  bundleBytes:before.length, bundleSHA256:createHash('sha256').update(before).digest('hex'),
  suites, compileOutput,
  notExecuted:['Ctrl/mouse/touch e renderização', 'Controladores completos no engine', 'Paredes reais e multiplayer', 'Respawn real R6/R15 e streaming', 'Reexecução via BindableFunction no engine', 'FPS e console Roblox'],
};
await writeFile(path.join(root,'tests','v2-local-results.json'),JSON.stringify(result,null,2)+'\n');
console.log(`${result.passedTests} testes; ${result.compiledFiles} arquivos compilados; build determinístico.`);
