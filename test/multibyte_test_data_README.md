# Multi-byte Test Data Files

This directory contains comprehensive test data files for testing virtual column operations with various character encodings and edge cases.

## Test Files Overview

### 1. `multibyte_ascii.txt`
**Purpose**: Baseline ASCII-only content for regression testing
**Content**: 
- Basic Latin characters, numbers, punctuation
- Lines of various lengths
- Tab and space combinations
- Ensures existing ASCII functionality remains unchanged

### 2. `multibyte_unicode.txt`  
**Purpose**: Unicode character testing (non-CJK)
**Content**:
- Accented characters (café, naïve, résumé)
- Greek letters (α, β, γ, δ, ε)
- Mathematical symbols (∑, ∏, ∫, ∂, ∇, ∞)
- Currency symbols (€, £, ¥, ₹)
- Box drawing characters and arrows
- Mixed Unicode content in sentences

### 3. `multibyte_cjk.txt`
**Purpose**: CJK (Chinese, Japanese, Korean) character testing
**Content**:
- Chinese Simplified and Traditional
- Japanese Hiragana, Katakana, and Kanji
- Korean Hangul
- Mixed CJK content
- Technical terms in CJK languages
- Long CJK sentences for wrapping tests

### 4. `multibyte_emoji.txt`
**Purpose**: Emoji and complex Unicode sequences
**Content**:
- Basic emoji faces and symbols
- Animals, food, activities
- Complex emoji sequences (👨‍💻, 👩‍🔬, 👨‍👩‍👧‍👦)
- Flag emoji and skin tone modifiers
- Very long emoji sequences
- Mixed emoji with text

### 5. `multibyte_tabs.txt`
**Purpose**: Tab character handling with various character types
**Content**:
- Basic tab alignment
- Mixed tabs and spaces
- Code-like content with indentation
- Tab alignment with CJK characters
- Various tabstop settings testing
- Mixed tabs with Unicode and emoji

### 6. `multibyte_mixed.txt`
**Purpose**: Complex mixed character type scenarios
**Content**:
- All character types combined in single lines
- Real-world code examples
- Tab-separated data with mixed characters
- Edge cases with whitespace variations
- JavaScript code example with international content

### 7. `multibyte_edge_cases.txt`
**Purpose**: Boundary conditions and edge cases
**Content**:
- Empty lines and whitespace-only lines
- Single character lines
- Extremely long words without spaces
- Lines exactly at column limits
- Zero-width and combining characters
- Right-to-left text (Arabic, Hebrew)
- Unicode normalization test cases

### 8. `multibyte_code_example.py`
**Purpose**: Real-world Python code with multi-byte content
**Content**:
- Complete Python class with international text processing
- Multi-byte strings in code comments
- Dictionary with various language greetings
- Regular expressions for character type detection
- Realistic code formatting and indentation
- Comments in multiple languages

### 9. `multibyte_documentation.md`
**Purpose**: Comprehensive documentation with all character types
**Content**:
- Structured examples of each character type
- Testing scenarios and expected behaviors
- Code examples with syntax highlighting
- Alignment testing tables
- Performance testing guidelines
- Complete reference for virtual column behavior

## Character Type Coverage

### ASCII (Single-width)
- Basic Latin letters: a-z, A-Z
- Numbers: 0-9
- Punctuation: .,;:!?'"()[]{}
- Symbols: @#$%^&*+-=_|\/~`

### Unicode (Single-width)
- Accented Latin: café, naïve, résumé
- Greek letters: α, β, γ, δ, ε, ζ, η, θ
- Mathematical: ∑, ∏, ∫, ∂, ∇, ∞, ≈, ≠
- Currency: €, £, ¥, ₹, ₽, ₩, ₪, ₨
- Arrows: ←, →, ↑, ↓, ↔, ↕

### CJK (Double-width)
- Chinese Simplified: 中文字符测试
- Chinese Traditional: 中文字符測試  
- Japanese Hiragana: ひらがな
- Japanese Katakana: カタカナ
- Japanese Kanji: 漢字
- Korean Hangul: 한국어

### Emoji (Double-width)
- Basic faces: 😀, 😃, 😄, 😁, 😆
- Objects: 💻, 📱, 🖥️, ⌨️, 🖱️
- Animals: 🐶, 🐱, 🐭, 🐹, 🐰
- Complex sequences: 👨‍💻, 👩‍🔬, 🏳️‍🌈

### Special Characters
- Tab characters: \t (configurable width)
- Combining characters: é (e + ́)
- Zero-width joiners: 👨‍💻
- Right-to-left: مرحبا, שלום

## Testing Scenarios Covered

### 1. Virtual Column Conversion
- Byte position to virtual column position
- Virtual column position to byte position
- Character boundary handling
- Multi-byte character edge cases

### 2. String Splitting
- Split at virtual column positions
- Avoid splitting multi-byte characters
- Handle combining character sequences
- Tab expansion in splitting

### 3. Display Width Calculations
- Accurate width calculation for all character types
- Tab width handling with various tabstop settings
- Line length calculations for wrapping
- Alignment calculations for split-screen display

### 4. Text Wrapping
- Wrap text at virtual column boundaries
- Preserve character integrity
- Handle very long words
- Mixed character type wrapping

### 5. Performance Testing
- Large files with mixed character types
- Repeated operations on multi-byte content
- Memory usage with Unicode strings
- Comparison with ASCII-only performance

## Usage Instructions

### For Unit Testing
```vim
" Load test data
edit test/multibyte_mixed.txt
" Test virtual column functions
echo cleave#vcol_to_byte(getline(1), 20)
echo cleave#byte_to_vcol(getline(1), 15)
```

### For Integration Testing
```vim
" Test complete workflow
edit test/multibyte_cjk.txt
call cursor(1, 15)
Cleave
CleaveReflow 30
```

### For Performance Testing
```vim
" Benchmark with large mixed content
edit test/multibyte_documentation.md
" Time virtual column operations
let start = reltime()
for i in range(1000)
    call cleave#vcol_to_byte(getline(1), 50)
endfor
echo reltimestr(reltime(start))
```

## Expected Test Results

### Character Width Verification
- ASCII: 1 column per character
- Unicode (most): 1 column per character
- CJK: 2 columns per character
- Emoji: 2 columns per character (may vary)
- Tabs: Configurable (default 8, commonly 4)

### Boundary Behavior
- Splits should never occur mid-character
- Virtual column positions should align with character boundaries
- Tab positions should respect tabstop settings
- Combining characters should stay with base characters

### Performance Expectations
- Virtual column operations should have minimal performance impact
- ASCII-only content should maintain original performance
- Mixed content should degrade gracefully
- Memory usage should remain reasonable

## Maintenance Notes

- Test files use UTF-8 encoding
- Vim modelines set appropriate column limits
- Files include both short and long lines
- Edge cases are clearly documented
- Real-world examples provide practical testing scenarios

These test files provide comprehensive coverage for virtual column functionality testing and ensure robust handling of international text content.