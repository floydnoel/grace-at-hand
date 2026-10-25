import { execFileSync } from 'node:child_process';
const checks = [
  ['Node', process.version.slice(1), /^24\.18\.0$/],
  ['pnpm', ['pnpm', ['--version']], /^11\.25\.0$/],
  ['Xcode', ['xcodebuild', ['-version']], /^Xcode 26\.0\.1\n/],
  ['Swift', ['swift', ['--version']], /Swift version 6\.2(?:\s|$)/],
  ['XcodeGen', ['xcodegen', ['--version']], /Version: 2\.46\.0(?:\s|$)/]
];
let failed = false;
for (const [name, command, expected] of checks) {
  try {
    const version = typeof command === 'string' ? command : execFileSync(command[0], command[1], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
    if (!expected.test(version)) throw new Error(`version does not match the pin: ${version.split('\n')[0]}`);
    console.log(`${name}: ${version.split('\n')[0]}`);
  } catch (error) { console.error(`${name}: ${error.message.split('\n')[0]}`); failed = true; }
}
if (failed) { console.error('Use the toolchain pinned in README.md, or review and update the pins together.'); process.exitCode = 1; }
