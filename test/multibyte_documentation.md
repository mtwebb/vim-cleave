# Multi-byte Character Testing Documentation

This document contains various character types for testing virtual column operations in the Cleave plugin.

## Character Type Examples

### ASCII Characters
Basic Latin characters, numbers, and symbols:
- Letters: abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ
- Numbers: 0123456789
- Punctuation: .,;:!?'"()[]{}
- Symbols: @#$%^&*+-=_|\/~`

### Unicode Characters
Extended Latin and other Unicode symbols:
- Accented: café naïve résumé façade piñata
- Greek: α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ τ υ φ χ ψ ω
- Mathematical: ∑ ∏ ∫ ∂ ∇ ∞ ≈ ≠ ± × ÷ √ ∝ ∈ ∉ ∪ ∩ ⊂ ⊃
- Currency: € £ ¥ ₹ ₽ ₩ ₪ ₨ ₡ ₦ ₨ ₫ ₱ ₲ ₴ ₵ ₶ ₷ ₸ ₹ ₺
- Arrows: ← → ↑ ↓ ↔ ↕ ↖ ↗ ↘ ↙ ⇐ ⇒ ⇑ ⇓ ⇔ ⇕

### CJK Characters (Chinese, Japanese, Korean)

#### Chinese (Simplified)
- Basic: 中文字符测试文件
- Sentence: 这是一个用于测试虚拟列功能的中文文档。
- Technical: 计算机编程软件开发测试

#### Chinese (Traditional)
- Basic: 中文字符測試文件
- Sentence: 這是一個用於測試虛擬列功能的中文文檔。
- Technical: 計算機編程軟件開發測試

#### Japanese
- Hiragana: ひらがなのテストファイルです
- Katakana: カタカナノテストファイルデス
- Kanji: 日本語の漢字テストファイル
- Mixed: これは日本語のテストファイルです。プログラミングの勉強をしています。

#### Korean
- Hangul: 한국어 테스트 파일입니다
- Sentence: 이것은 가상 열 기능을 테스트하기 위한 한국어 문서입니다.
- Technical: 컴퓨터 프로그래밍 소프트웨어 개발 테스트

### Emoji Characters
Various emoji types for testing display width:

#### Basic Faces
😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🤩 🥳

#### Animals & Nature  
🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🙈 🙉 🙊 🐒 🐔 🐧 🐦 🐤 🐣 🐥 🦆 🦅 🦉 🦇 🐺 🐗

#### Food & Drink
🍎 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥬 🥒 🌶️ 🫑 🌽 🥕 🫒 🧄 🧅 🥔 🍠

#### Activities & Objects
⚽ 🏀 🏈 ⚾ 🥎 🎾 🏐 🏉 🥏 🎱 🪀 🏓 🏸 🏒 🏑 🥍 🏏 🪃 🥅 ⛳ 🪁 🏹 🎣 🤿 🥊 🥋 🎽 🛹 🛼 ⛸️ 🥌

#### Symbols & Flags
⭐ 🌟 ✨ 💫 ⚡ 🔥 💥 ☄️ ☀️ 🌤️ ⛅ 🌦️ 🌧️ ⛈️ 🌩️ 🌨️ ❄️ ☃️ ⛄ 🌬️ 💨 🌪️ 🌫️ 🌈 ☔ ⚡ ❄️

## Testing Scenarios

### Line Length Testing
Lines of various lengths to test wrapping behavior:

Short: Hi 👋
Medium: Hello world with emoji 🌍 and CJK 中文
Long: This is a longer line that contains ASCII text, Unicode characters like café and résumé, CJK characters 中文字符, and emoji 🎯🌟✨ to test wrapping behavior.
Very Long: This is an extremely long line designed to test the virtual column wrapping functionality with a comprehensive mix of character types including ASCII letters and numbers, Unicode accented characters like café naïve résumé, Chinese characters 中文字符测试, Japanese text 日本語のテスト, Korean text 한국어 테스트, mathematical symbols ∑∏∫∂∇, and various emoji 🎯🌟✨💫⭐🔥💥🌈🦄🎪 to ensure proper handling of display width calculations.

### Alignment Testing
Testing alignment with different character widths:

```
Name     | Age | City      | Country | Status
---------|-----|-----------|---------|--------
John     | 25  | New York  | USA     | Active ✅
田中太郎   | 30  | 東京       | 日本     | 待機中 ⏳
김철수     | 35  | 서울       | 한국     | 완료 ✅
José     | 28  | Madrid    | España  | Activo ✅
محمد      | 32  | القاهرة    | مصر     | نشط ✅
```

### Code Examples
Real-world code with multi-byte content:

```python
def greet_user(name: str, language: str) -> str:
    """Greet user in their preferred language."""
    greetings = {
        'en': f'Hello, {name}! 👋',
        'zh': f'你好，{name}！🇨🇳',
        'ja': f'こんにちは、{name}さん！🇯🇵',
        'ko': f'안녕하세요, {name}님! 🇰🇷',
        'es': f'¡Hola, {name}! 🇪🇸',
        'fr': f'Bonjour, {name}! 🇫🇷'
    }
    return greetings.get(language, f'Hello, {name}!')

# Test with international names
users = ['John', '田中', '김철수', 'José', 'محمد']
for user in users:
    print(greet_user(user, 'en'))  # Mixed output
```

### Edge Cases

#### Empty and Whitespace Lines


   
	
    	    

#### Single Characters
A
中
🎯
∑

#### Boundary Conditions
Exactly at limit: 1234567890123456789012345
One over limit: 12345678901234567890123456
CJK at boundary: 中文字符测试1234567890123456789

#### Mixed Whitespace
	Tab then spaces    
    Spaces then tab	
	Mixed	spacing	with	中文	characters
    Mixed    spacing    with    emoji 🎯 characters

## Testing Instructions

1. **Virtual Column Conversion**: Test `cleave#vcol_to_byte()` and `cleave#byte_to_vcol()` with each character type
2. **String Splitting**: Test `cleave#virtual_strpart()` with mixed content
3. **Display Width**: Verify `strdisplaywidth()` calculations match expected values
4. **Wrapping**: Test text wrapping at various column widths
5. **Alignment**: Verify proper alignment in split-screen mode
6. **Performance**: Benchmark operations with large multi-byte files

## Expected Behavior

- ASCII characters: 1 display column each
- Most Unicode characters: 1 display column each  
- CJK characters: 2 display columns each
- Most emoji: 2 display columns each
- Tab characters: Configurable (default 8, often set to 4)
- Combining characters: 0 display columns (combine with base character)

## Notes

This documentation serves as both a reference and a comprehensive test file for virtual column operations. Each section can be used independently or combined for complex testing scenarios.