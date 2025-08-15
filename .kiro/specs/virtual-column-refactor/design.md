# Design Document

## Overview

This design outlines the refactoring of vim-cleave from byte-based column operations to virtual column operations. The refactoring will replace byte-oriented functions with display-width-aware equivalents to properly handle multi-byte characters, tabs, and wide characters.

## Architecture

The refactoring follows a function-by-function replacement strategy:

1. **Column Position Functions**: Replace `col('.')` with `virtcol('.')`
2. **String Splitting Functions**: Replace `strpart()` with custom virtual column-aware splitting
3. **Length Calculation Functions**: Replace `len()` with `strdisplaywidth()` for display calculations
4. **Padding Calculation Functions**: Update join operations to use display width

## Components and Interfaces

### Core Functions to Modify

#### 1. `cleave#split_buffer()`
- **Current**: Uses `col('.')` to get cursor position
- **New**: Use `virtcol('.')` to get virtual cursor position
- **Impact**: Entry point for all cleave operations

#### 2. `cleave#split_content()`
- **Current**: Uses `strpart(line, 0, split_col - 1)` and `strpart(line, split_col - 1)`
- **New**: Implement virtual column-aware string splitting
- **Impact**: Core splitting logic

#### 3. `cleave#setup_windows()`
- **Current**: Uses byte-based column for window sizing
- **New**: Use virtual column for window resize calculations
- **Impact**: Window layout and sizing

#### 4. `cleave#join_buffers()`
- **Current**: Uses `strdisplaywidth()` for left line length (already correct)
- **New**: Verify all padding calculations use display width
- **Impact**: Buffer rejoining accuracy

#### 5. Text width and reflow functions
- **Current**: Mix of `len()` and `strdisplaywidth()`
- **New**: Consistently use `strdisplaywidth()` for all display calculations
- **Impact**: Text reflow and wrapping accuracy

### New Helper Functions

#### `cleave#virtual_strpart(string, start_vcol, end_vcol)`
Custom function to extract substring based on virtual column positions:
- Convert virtual columns to byte positions
- Handle multi-byte character boundaries
- Ensure clean character splits (no partial characters)

#### `cleave#vcol_to_byte(string, vcol)`
Convert virtual column position to byte position in a string:
- Iterate through characters calculating display width
- Return byte position corresponding to virtual column
- Handle edge cases (beyond string end, mid-character positions)

#### `cleave#byte_to_vcol(string, byte_pos)`
Convert byte position to virtual column position:
- Calculate cumulative display width up to byte position
- Handle multi-byte character boundaries
- Return virtual column position

## Data Models

### Column Position Tracking
```vim
" Current approach (byte-based)
let cleave_col = col('.')  " Byte position
let left_part = strpart(line, 0, cleave_col - 1)  " Byte-based split

" New approach (virtual column-based)
let cleave_vcol = virtcol('.')  " Virtual column position
let left_part = cleave#virtual_strpart(line, 1, cleave_vcol - 1)  " Virtual column-based split
```

### Buffer Variables
- `cleave_col`: Change from byte column to virtual column
- All existing buffer variables remain compatible
- Window sizing calculations updated to use virtual columns

## Error Handling

### Multi-byte Character Boundaries
- When splitting mid-character, round to character boundary
- Prefer including complete characters in left buffer
- Provide user feedback for boundary adjustments

### Tab Handling
- Respect `tabstop` setting for tab width calculation
- Handle mixed tabs and spaces correctly
- Maintain visual alignment across different tab settings

### Wide Character Support
- Detect and handle double-width characters (CJK, emojis)
- Use `strdisplaywidth()` consistently for width calculations
- Handle zero-width characters appropriately

## Testing Strategy

### Unit Tests
1. **Character Type Tests**
   - ASCII-only text (regression testing)
   - Unicode characters (basic multilingual plane)
   - Wide characters (CJK, emojis)
   - Tab characters with various tabstop settings
   - Mixed character types

2. **Function-Level Tests**
   - `cleave#virtual_strpart()` with various inputs
   - `cleave#vcol_to_byte()` conversion accuracy
   - `cleave#byte_to_vcol()` conversion accuracy
   - Column position detection accuracy

3. **Integration Tests**
   - Split at various virtual column positions
   - Join operations with multi-byte content
   - Reflow operations with wide characters
   - Window sizing with mixed character content

### Test Data Sets
- Sample text files with various character encodings
- Edge cases: empty lines, very long lines, all-whitespace lines
- Real-world examples: code with Unicode identifiers, documentation with emojis

### Regression Testing
- Ensure ASCII-only behavior remains identical
- Verify existing cleaved buffers continue to work
- Test all existing commands with new implementation

## Implementation Phases

### Phase 1: Core Virtual Column Functions
- Implement `cleave#virtual_strpart()`
- Implement `cleave#vcol_to_byte()` and `cleave#byte_to_vcol()`
- Add comprehensive unit tests for these functions

### Phase 2: Split Operations
- Update `cleave#split_buffer()` to use `virtcol('.')`
- Update `cleave#split_content()` to use virtual column splitting
- Update `cleave#setup_windows()` for virtual column sizing

### Phase 3: Join Operations
- Verify and update `cleave#join_buffers()` padding calculations
- Ensure all length calculations use `strdisplaywidth()`

### Phase 4: Reflow Operations
- Update all reflow functions to use display width consistently
- Update text width calculations
- Update paragraph boundary detection

### Phase 5: Testing and Validation
- Comprehensive testing with various character sets
- Performance testing to ensure no significant regression
- Documentation updates

## Performance Considerations

### Character Width Calculation Caching
- `strdisplaywidth()` can be expensive for long strings
- Consider caching results for frequently accessed lines
- Profile performance impact on large files

### Incremental Processing
- Process strings character by character only when necessary
- Use built-in functions where possible
- Optimize common cases (ASCII-only text)

## Backward Compatibility

### Command Interface
- All existing commands maintain same syntax
- Column numbers in commands interpreted as virtual columns
- No breaking changes to user interface

### Buffer Variables
- `cleave_col` values updated to virtual columns
- Existing cleaved buffers may need migration logic
- Provide fallback for legacy buffer variables

## Migration Strategy

### Gradual Rollout
1. Implement new functions alongside existing ones
2. Add feature flag to enable virtual column mode
3. Test extensively with feature flag enabled
4. Make virtual column mode the default
5. Remove old byte-based functions after validation period

### User Communication
- Document the change in behavior for multi-byte characters
- Provide examples showing improved behavior
- Explain any edge cases or limitations