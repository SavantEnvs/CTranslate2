// Fuzzes the vocabulary map parser ("<n-gram>\t<candidate> <candidate> ...", one rule per line)
// and the candidate lookup for a small fixed vocabulary.
#include <cstddef>
#include <cstdint>
#include <exception>
#include <sstream>
#include <string>
#include <vector>

#include <ctranslate2/vocabulary.h>
#include <ctranslate2/vocabulary_map.h>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  using namespace ctranslate2;

  static const Vocabulary vocabulary(
    {"<blank>", "<s>", "</s>", "the", "cat", "sat", "on", "mat", "a", "dog"});

  // The map file always starts with the rule holding the always-allowed candidates (key "", see
  // vocabulary_map.h); a file with no lines at all crashes the constructor (_map_rules[0] on an empty
  // vector), recorded in known-findings/ rather than rediscovered by every input.
  std::string content = "\t<s>\n";
  content.append(reinterpret_cast<const char*>(data), size);
  std::istringstream in(content);
  try {
    VocabularyMap map(in, vocabulary);
    map.get_candidates({{"the", "cat", "sat"}, {"a", "dog"}, {"unknown"}}, {});
    map.get_candidates({{"on", "the", "mat"}}, {{3, 4}});
  } catch (const std::exception&) {
    return -1;
  }
  return 0;
}
