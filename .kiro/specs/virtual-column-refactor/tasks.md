# Implementation Plan

- [x] 1. Create virtual column utility functions
  - Implement core helper functions for virtual column operations
  - Add comprehensive unit tests for character width calculations
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 1.1 Implement cleave#vcol_to_byte() conversion function
  - Write function to convert virtual column position to byte position in a string
  - Handle multi-byte characters, tabs, and wide characters correctly
  - Create unit tests with ASCII, Unicode, CJK, and emoji test cases
  - _Requirements: 4.2, 1.1, 1.3_

- [x] 1.2 Implement cleave#byte_to_vcol() conversion function
  - Write function to convert byte position to virtual column position
  - Handle character boundary edge cases and string end conditions
  - Create unit tests for various character encodings and edge cases
  - _Requirements: 4.2, 1.1, 1.3_

- [x] 1.3 Implement cleave#virtual_strpart() string splitting function
  - Write function to extract substring based on virtual column positions
  - Ensure clean character splits without partial multi-byte characters
  - Create comprehensive tests for string splitting with mixed character types
  - _Requirements: 4.2, 1.1, 1.2, 1.3_

- [ ] 2. Update core splitting functionality
  - Modify main buffer splitting functions to use virtual columns
  - Update cursor position detection and window sizing
  - _Requirements: 1.1, 1.2, 4.1, 4.4_

- [ ] 2.1 Update cleave#split_buffer() to use virtcol()
  - Replace col('.') with virtcol('.') for cursor position detection
  - Update column parameter handling to interpret as virtual columns
  - Add validation tests with multi-byte characters at cursor position
  - _Requirements: 1.1, 4.1, 5.1_

- [ ] 2.2 Refactor cleave#split_content() for virtual column splitting
  - Replace strpart() calls with cleave#virtual_strpart() function
  - Update string splitting logic to handle virtual column positions
  - Create tests for splitting lines with various character types
  - _Requirements: 1.1, 1.2, 4.2_

- [ ] 2.3 Update cleave#setup_windows() for virtual column sizing
  - Modify window resize calculations to use virtual column widths
  - Update foldcolumn and gutter calculations for display width
  - Test window sizing with wide characters and tabs
  - _Requirements: 1.3, 4.4_

- [ ] 3. Update buffer joining operations
  - Verify and enhance join operations for virtual column alignment
  - Ensure padding calculations use display width consistently
  - _Requirements: 2.1, 2.2, 2.3, 4.3_

- [ ] 3.1 Verify cleave#join_buffers() padding calculations
  - Review existing strdisplaywidth() usage in padding calculations
  - Add tests for joining buffers with multi-byte characters
  - Ensure cleave_column calculation accounts for display width
  - _Requirements: 2.1, 2.2, 4.3_

- [ ] 3.2 Update combined line construction logic
  - Verify that left_len calculation uses strdisplaywidth()
  - Test padding calculation with various character widths
  - Add comprehensive tests for join operations with mixed character types
  - _Requirements: 2.2, 2.3_

- [ ] 4. Update text reflow and width calculations
  - Modify all text reflow functions to use display width consistently
  - Update textwidth calculations and paragraph handling
  - _Requirements: 3.1, 3.2, 3.3, 4.3_

- [ ] 4.1 Update cleave#set_textwidth_to_longest_line() function
  - Ensure line length calculation uses strdisplaywidth() instead of len()
  - Remove trailing whitespace before calculating display width
  - Add tests with lines containing wide characters and tabs
  - _Requirements: 3.3, 4.3_

- [ ] 4.2 Update cleave#reflow_text() for display width wrapping
  - Verify paragraph wrapping uses display width for line length calculations
  - Update cleave#wrap_paragraph() to handle character display widths
  - Test text reflow with various character encodings
  - _Requirements: 3.1, 3.2, 4.3_

- [ ] 4.3 Update paragraph boundary detection functions
  - Review cleave#reflow_left_buffer() and cleave#reflow_right_buffer()
  - Ensure first word matching handles multi-byte characters correctly
  - Test paragraph alignment with wide characters
  - _Requirements: 3.2, 3.3_

- [ ] 5. Add comprehensive testing suite
  - Create test files with various character encodings
  - Implement automated tests for all virtual column operations
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_

- [ ] 5.1 Create test data files with multi-byte content
  - Create test files with ASCII, Unicode, CJK, emoji, and tab characters
  - Include edge cases like empty lines, very long lines, mixed content
  - Add real-world examples with code and documentation
  - _Requirements: 1.1, 1.2, 1.3_

- [ ] 5.2 Implement unit tests for virtual column functions
  - Write comprehensive tests for cleave#vcol_to_byte() and cleave#byte_to_vcol()
  - Test cleave#virtual_strpart() with various character combinations
  - Add performance benchmarks for character width calculations
  - _Requirements: 4.1, 4.2, 4.3_

- [ ] 5.3 Create integration tests for complete workflows
  - Test split-join roundtrip operations with multi-byte content
  - Test reflow operations with wide characters and tabs
  - Verify window sizing and alignment with various character types
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_

- [ ] 6. Add regression testing for ASCII compatibility
  - Ensure existing ASCII-only workflows remain unchanged
  - Verify backward compatibility with existing cleaved buffers
  - _Requirements: 5.1, 5.2, 5.3_

- [ ] 6.1 Create ASCII-only regression test suite
  - Test all existing functionality with ASCII-only content
  - Verify identical behavior to current implementation
  - Add performance comparison tests
  - _Requirements: 5.1, 5.2_

- [ ] 6.2 Test backward compatibility with existing buffers
  - Create test scenarios with pre-existing cleaved buffers
  - Verify that buffer variables and state remain compatible
  - Test migration of byte-based cleave_col values
  - _Requirements: 5.3_

- [ ] 7. Update error handling and edge cases
  - Add proper error handling for character boundary issues
  - Implement user feedback for column position adjustments
  - _Requirements: 1.1, 1.2, 1.3_

- [ ] 7.1 Implement character boundary error handling
  - Add logic to handle splits that fall mid-character
  - Implement rounding to nearest character boundary
  - Provide user feedback when column position is adjusted
  - _Requirements: 1.1_

- [ ] 7.2 Add tab handling and mixed whitespace support
  - Ensure tab width calculations respect tabstop setting
  - Handle mixed tabs and spaces in column calculations
  - Test with various tabstop values and mixed whitespace
  - _Requirements: 1.3_

- [ ] 8. Performance optimization and validation
  - Profile performance impact of virtual column operations
  - Optimize common cases and add caching where beneficial
  - _Requirements: 4.1, 4.2, 4.3_

- [ ] 8.1 Profile performance of character width calculations
  - Benchmark strdisplaywidth() performance on large files
  - Identify performance bottlenecks in virtual column operations
  - Implement caching for frequently accessed line width calculations
  - _Requirements: 4.3_

- [ ] 8.2 Optimize ASCII-only code paths
  - Add fast path for ASCII-only content to maintain performance
  - Use built-in functions where possible for common cases
  - Validate that performance regression is minimal
  - _Requirements: 5.1, 5.2_