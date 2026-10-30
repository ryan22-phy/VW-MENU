import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const modules = ['config', 'cleanup', 'tracker', 'aim', 'esp', 'ui', 'main'];
let output = '-- VW MENU v2 | LocalScript cliente | testes autorizados\n';
output += '-- Gerado por tools/build-v2.mjs. Edite src/v2/ e gere novamente.\n';
for (const name of modules) {
  let source = await readFile(path.join(root, 'src', 'v2', name + '.lua'), 'utf8');
  source = source.replace(/require\(script\.Parent\.([a-z]+)\)/g, (_, dependency) => {
    if (!modules.includes(dependency) || modules.indexOf(dependency) >= modules.indexOf(name)) {
      throw new Error(`Dependência inválida ou circular: ${name} -> ${dependency}`);
    }
    return '__' + dependency;
  });
  if (/\brequire\s*\(/.test(source)) throw new Error(`Import não resolvido em ${name}`);
  output += `\nlocal __${name} = (function()\n${source.trim()}\nend)()\n`;
}
output += '\nreturn __main.start()\n';
await mkdir(path.join(root, 'dist'), {recursive:true});
const destination = path.join(root, 'dist', 'VW-MENU.lua');
await writeFile(destination, output, 'utf8');
console.log(`dist/VW-MENU.lua: ${Buffer.byteLength(output)} bytes; ${modules.length} módulos integrados.`);
