import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';
import {fileURLToPath} from 'node:url';
const path=(p)=>fileURLToPath(new URL(p,import.meta.url));
export default defineConfig({root:path('./'),publicDir:path('../public'),plugins:[react()],resolve:{alias:{'@':path('../')}},css:{postcss:path('../')},build:{outDir:path('../dist-eq'),emptyOutDir:true}});
