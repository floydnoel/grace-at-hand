# Shared artwork

`cloister.png` is the original generated cloister/olive-tree hero, shared by future native and web clients. `tools/bundle-assets.mjs` copies it into the iOS asset catalog during generation. Do not edit the generated copy.

See `docs/design/assets.md` for the exact generation prompt and review status. Native arch and evening compositions use code/SF Symbols; future platforms should recreate their geometry with the same shared semantic colors rather than extracting Apple symbol files.
