# Requirements Document

## Introduction

The vim-cleave plugin currently uses byte-based column operations which causes incorrect splitting behavior when dealing with multi-byte characters (Unicode, emojis, wide characters, etc.). This refactoring will convert the plugin to use virtual columns, ensuring that the visual column position matches the split position regardless of character encoding.

## Requirements

### Requirement 1

**User Story:** As a user editing text with multi-byte characters, I want cleave to split at the correct visual column position, so that the split appears where I expect it visually.

#### Acceptance Criteria

1. WHEN the user positions the cursor on a multi-byte character THEN cleave SHALL split at the correct visual column position
2. WHEN the user specifies a column number with CleaveAtColumn THEN cleave SHALL interpret this as a virtual column position
3. WHEN text contains tabs, Unicode characters, or wide characters THEN cleave SHALL maintain correct visual alignment

### Requirement 2

**User Story:** As a user working with mixed character encodings, I want the join operation to preserve correct spacing, so that the rejoined text maintains proper visual alignment.

#### Acceptance Criteria

1. WHEN joining cleaved buffers with multi-byte characters THEN the system SHALL calculate padding based on display width
2. WHEN the left buffer contains wide characters THEN the system SHALL account for their display width in padding calculations
3. WHEN rejoining text THEN the visual column alignment SHALL match the original cleave position

### Requirement 3

**User Story:** As a user reflowing text with multi-byte characters, I want the reflow to respect character display widths, so that text wrapping occurs at the correct visual boundaries.

#### Acceptance Criteria

1. WHEN reflowing text with wide characters THEN the system SHALL use display width for line length calculations
2. WHEN determining paragraph boundaries THEN the system SHALL handle multi-byte characters correctly
3. WHEN setting textwidth THEN the system SHALL account for character display widths

### Requirement 4

**User Story:** As a developer, I want the plugin to use consistent virtual column functions throughout, so that all column operations behave predictably with any character encoding.

#### Acceptance Criteria

1. WHEN any function needs cursor column position THEN it SHALL use virtcol() instead of col()
2. WHEN any function needs to split strings THEN it SHALL use display-width-aware functions
3. WHEN any function calculates string lengths THEN it SHALL use strdisplaywidth() instead of len()
4. WHEN window sizing is calculated THEN it SHALL account for character display widths

### Requirement 5

**User Story:** As a user, I want the plugin to maintain backward compatibility, so that existing workflows continue to work without changes.

#### Acceptance Criteria

1. WHEN using existing commands THEN they SHALL work with the same syntax and behavior
2. WHEN working with ASCII-only text THEN the behavior SHALL remain identical to the current implementation
3. WHEN upgrading the plugin THEN existing cleaved buffers SHALL continue to work correctly