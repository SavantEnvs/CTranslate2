# Null dereference on an empty vocabulary-map file

- Found by reading `src/vocabulary_map.cc`, confirmed with `repro.cc` (link against the sanitized `libctranslate2.a`): SEGV at address 0x18.
- Cause: the constructor looks up the empty-key entry in `_map_rules[0]` (src/vocabulary_map.cc:47) without checking that any rule was read, so the vector is empty.
- Impact: an empty or comment-only map file crashes the loader instead of raising an error.
- Fix: throw if no rules were read before indexing `_map_rules`.
- The harness prepends `"\t<s>\n"` to every input so fuzzing explores the rule parser instead of stopping at this crash.
