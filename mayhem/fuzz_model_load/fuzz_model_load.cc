// Fuzzes the CTranslate2 model loader (binary model.bin parser, variable/spec resolution, layer
// construction) and, when the model loads, one short translation through the loaded weights.
#include <cstddef>
#include <cstdint>
#include <exception>
#include <string>

#include <ctranslate2/devices.h>
#include <ctranslate2/models/model.h>
#include <ctranslate2/models/model_reader.h>
#include <ctranslate2/models/sequence_to_sequence.h>
#include <ctranslate2/translation.h>

#include "vocabulary.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  using namespace ctranslate2;

  models::ModelMemoryReader reader("fuzz");
  reader.register_file("model.bin", std::string(reinterpret_cast<const char*>(data), size));
  reader.register_file("source_vocabulary.txt", kSourceVocabulary);
  reader.register_file("target_vocabulary.txt", kTargetVocabulary);

  try {
    auto model = models::Model::load(reader, Device::CPU);
    auto replica = model->as_sequence_to_sequence();
    TranslationOptions options;
    options.beam_size = 2;
    options.max_decoding_length = 4;
    replica->translate({kSourceTokens}, {}, options);
  } catch (const std::exception&) {
    return -1;
  }
  return 0;
}
