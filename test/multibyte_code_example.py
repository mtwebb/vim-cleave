#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Real-world code example with multi-byte content for testing.
This file contains various character types in comments and strings.
"""

import re
from typing import Dict, List, Optional

class InternationalTextProcessor:
    """
    A class for processing international text with various character encodings.
    Supports ASCII, Unicode, CJK (中日韩), and emoji characters.
    """
    
    def __init__(self):
        # Dictionary with multi-byte keys and values
        self.greetings = {
            'english': 'Hello World! 👋',
            'chinese': '你好世界！🌍',
            'japanese': 'こんにちは世界！🗾',
            'korean': '안녕하세요 세계！🇰🇷',
            'french': 'Bonjour le monde！🇫🇷',
            'spanish': '¡Hola mundo！🇪🇸',
            'arabic': 'مرحبا بالعالم！🌎',
            'emoji': '👋🌍🎉✨🚀💻🎯'
        }
        
        # Regular expressions for different character types
        self.patterns = {
            'ascii': re.compile(r'[a-zA-Z0-9\s]'),
            'cjk': re.compile(r'[\u4e00-\u9fff\u3400-\u4dbf\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af]'),
            'emoji': re.compile(r'[\U0001F600-\U0001F64F\U0001F300-\U0001F5FF\U0001F680-\U0001F6FF\U0001F1E0-\U0001F1FF]'),
            'unicode': re.compile(r'[^\x00-\x7F]')
        }
    
    def analyze_text(self, text: str) -> Dict[str, int]:
        """
        Analyze text and count different character types.
        
        Args:
            text: Input text with potentially mixed character encodings
            
        Returns:
            Dictionary with character type counts
            
        Example:
            >>> processor = InternationalTextProcessor()
            >>> result = processor.analyze_text("Hello 世界 🌍")
            >>> print(result)  # {'ascii': 6, 'cjk': 2, 'emoji': 1, 'total': 9}
        """
        result = {
            'ascii': len(self.patterns['ascii'].findall(text)),
            'cjk': len(self.patterns['cjk'].findall(text)),
            'emoji': len(self.patterns['emoji'].findall(text)),
            'unicode': len(self.patterns['unicode'].findall(text)),
            'total': len(text),
            'display_width': self._calculate_display_width(text)
        }
        return result
    
    def _calculate_display_width(self, text: str) -> int:
        """
        Calculate display width considering multi-byte characters.
        CJK characters typically take 2 columns, emoji may vary.
        """
        width = 0
        for char in text:
            if self.patterns['cjk'].match(char):
                width += 2  # CJK characters are typically double-width
            elif self.patterns['emoji'].match(char):
                width += 2  # Most emoji are double-width
            elif char == '\t':
                width += 4  # Assuming tab width of 4
            else:
                width += 1  # ASCII and most Unicode characters
        return width
    
    def format_multilingual_output(self, data: List[Dict]) -> str:
        """
        Format output with proper alignment for multi-byte characters.
        
        This function demonstrates the challenges of text alignment
        when dealing with characters of different display widths.
        """
        output_lines = []
        
        # Header with mixed characters
        header = "Name 名前 이름 | Age 年齢 나이 | City 城市 도시 | Status 状态 상태"
        output_lines.append(header)
        output_lines.append("-" * self._calculate_display_width(header))
        
        # Sample data with international names and cities
        sample_data = [
            {"name": "John Smith", "age": 25, "city": "New York", "status": "Active ✅"},
            {"name": "田中太郎", "age": 30, "city": "東京", "status": "待機中 ⏳"},
            {"name": "김철수", "age": 35, "city": "서울", "status": "완료 ✅"},
            {"name": "José García", "age": 28, "city": "Madrid", "status": "En progreso 🔄"},
            {"name": "محمد أحمد", "age": 32, "city": "القاهرة", "status": "نشط ✅"}
        ]
        
        for item in sample_data:
            # This is where proper virtual column handling becomes crucial
            line = f"{item['name']} | {item['age']} | {item['city']} | {item['status']}"
            output_lines.append(line)
        
        return '\n'.join(output_lines)
    
    def test_edge_cases(self) -> List[str]:
        """Test various edge cases with multi-byte content."""
        test_cases = [
            "",  # Empty string
            " ",  # Single space
            "\t",  # Single tab
            "A",  # Single ASCII character
            "中",  # Single CJK character
            "🎯",  # Single emoji
            "A中🎯",  # Mixed single characters
            "Hello 世界 🌍",  # Mixed short phrase
            "这是一个很长的中文句子用来测试换行功能",  # Long CJK text
            "🎉🎊🎈🎁🎂🍰🧁🍭🍬🍫🍩🍪🎯🎲🎮",  # Long emoji sequence
            "Mixed: ASCII + 中文 + emoji 🎯 + symbols ∑∏∫",  # All types mixed
            "Line with\ttabs\tand\tCJK\t中文\ttabs",  # Tabs with CJK
            "Café naïve résumé façade",  # Unicode accents
            "∑∏∫∂∇∞≈≠±×÷√∝∈∉∪∩⊂⊃⊆⊇",  # Mathematical symbols
            "←→↑↓↔↕↖↗↘↙⇐⇒⇑⇓⇔⇕",  # Arrow symbols
        ]
        return test_cases

def main():
    """
    Main function demonstrating multi-byte text processing.
    This serves as a real-world example for testing virtual column operations.
    """
    processor = InternationalTextProcessor()
    
    # Test with various greetings
    print("=== Multi-language Greetings ===")
    for lang, greeting in processor.greetings.items():
        analysis = processor.analyze_text(greeting)
        print(f"{lang:10}: {greeting:30} (width: {analysis['display_width']:2})")
    
    print("\n=== Formatted Output Test ===")
    formatted_output = processor.format_multilingual_output([])
    print(formatted_output)
    
    print("\n=== Edge Case Tests ===")
    edge_cases = processor.test_edge_cases()
    for i, case in enumerate(edge_cases):
        analysis = processor.analyze_text(case)
        print(f"Case {i:2}: '{case}' -> width: {analysis['display_width']}")

if __name__ == "__main__":
    main()

# Comments in various languages for testing:
# English: This is a test comment
# 中文：这是一个测试注释
# 日本語：これはテストコメントです
# 한국어: 이것은 테스트 주석입니다
# Français: Ceci est un commentaire de test
# Español: Este es un comentario de prueba
# العربية: هذا تعليق اختبار
# Emoji: This is a test comment 🧪🔬⚗️