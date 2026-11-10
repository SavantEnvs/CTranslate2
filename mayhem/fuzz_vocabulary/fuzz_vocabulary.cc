// Fuzzes the vocabulary file parsers (text: one token per line; JSON: array of tokens or a
// token->id object) and the token/id lookups on whatever vocabulary they produce.
// The first input byte only selects the parser, the rest is the file content.
#include <cstddef>
#include <cstdint>
#include <exception>
#include <sstream>
#include <string>
#include <vector>

#include <ctranslate2/vocabulary.h>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  using namespace ctranslate2;
  if (size == 0)
    return -1;

  std::istringstream in(std::string(reinterpret_cast<const char*>(data + 1), size - 1));
  try {
    Vocabulary vocabulary = (data[0] & 1) ? Vocabulary::from_json_file(in)
                                          : Vocabulary::from_text_file(in);
    const size_t n = vocabulary.size();
    std::vector<std::string> tokens;
    for (size_t i = 0; i < n && i < 16; ++i)
      tokens.push_back(vocabulary.to_token(i));
    tokens.push_back("not-in-vocabulary");
    vocabulary.to_ids({tokens}, 8, true, true);
    vocabulary.to_ids({tokens}, 0, nullptr, nullptr, false);
    vocabulary.contains(vocabulary.unk_token());
  } catch (const std::exception&) {
    return -1;
  }
  return 0;
}
