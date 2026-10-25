import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const tokens = JSON.parse(await readFile(`${root}shared/design-tokens/tokens.json`, 'utf8'));
const colors = Object.entries(tokens.colors).map(([name, value]) => `    static let ${name} = adaptive(0x${value.light}, 0x${value.dark}, 0x${value.lightHigh ?? value.light}, 0x${value.darkHigh ?? value.dark})`).join('\n');
const source = `// Generated from shared/design-tokens/tokens.json. Run make generate.\nimport SwiftUI\nimport UIKit\n\nenum GraceColor {\n${colors}\n\n    private static func adaptive(_ light: UInt, _ dark: UInt, _ lightHigh: UInt, _ darkHigh: UInt) -> Color {\n        Color(uiColor: UIColor { traits in\n            let high = traits.accessibilityContrast == .high\n            let value = traits.userInterfaceStyle == .dark ? (high ? darkHigh : dark) : (high ? lightHigh : light)\n            return UIColor(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, alpha: 1)\n        })\n    }\n}\n\nenum GraceLayout {\n${Object.entries(tokens.layout).map(([k,v]) => `    static let ${k}: CGFloat = ${v}`).join('\n')}\n}\n`;
await mkdir(`${root}ios/App/Design`, { recursive: true });
await writeFile(`${root}ios/App/Design/GeneratedTokens.swift`, source);
