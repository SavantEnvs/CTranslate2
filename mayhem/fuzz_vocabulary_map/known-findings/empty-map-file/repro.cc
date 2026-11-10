#include <sstream>
#include <ctranslate2/vocabulary.h>
#include <ctranslate2/vocabulary_map.h>
int main() {
  ctranslate2::Vocabulary v({"<blank>", "<s>", "</s>", "a"});
  std::istringstream in("");
  ctranslate2::VocabularyMap m(in, v);
}
