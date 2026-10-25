import { copyFile, mkdir } from 'node:fs/promises';
const destination = new URL('../ios/App/Resources/Assets.xcassets/Cloister.imageset/', import.meta.url);
await mkdir(destination, { recursive: true });
await copyFile(new URL('../shared/assets/cloister.png', import.meta.url), new URL('cloister.png', destination));
