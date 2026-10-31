module dbc.cpp_gen;

import std.array;
import std.format;
import dbc.model;

string generateCppHeader(Database db) {
    Appender!string outBuffer;
    
    outBuffer.put("#pragma once\n");
    outBuffer.put("#include <cstdint>\n");
    outBuffer.put("#include <cstring>\n\n");
    
    outBuffer.put("namespace can {\n\n");
    
    outBuffer.put("inline uint64_t extract_bits_little(const uint8_t* data, int start_bit, int length) {\n");
    outBuffer.put("    uint64_t payload = 0;\n");
    outBuffer.put("    std::memcpy(&payload, data, 8);\n");
    outBuffer.put("    uint64_t mask = length == 64 ? ~0ULL : (1ULL << length) - 1;\n");
    outBuffer.put("    return (payload >> start_bit) & mask;\n");
    outBuffer.put("}\n\n");
    
    outBuffer.put("inline void insert_bits_little(uint8_t* data, uint64_t value, int start_bit, int length) {\n");
    outBuffer.put("    uint64_t payload = 0;\n");
    outBuffer.put("    std::memcpy(&payload, data, 8);\n");
    outBuffer.put("    uint64_t mask = length == 64 ? ~0ULL : (1ULL << length) - 1;\n");
    outBuffer.put("    payload &= ~(mask << start_bit);\n");
    outBuffer.put("    payload |= (value & mask) << start_bit;\n");
    outBuffer.put("    std::memcpy(data, &payload, 8);\n");
    outBuffer.put("}\n\n");

    outBuffer.put("inline uint64_t bswap64(uint64_t val) {\n");
    outBuffer.put("    return ((val & 0xFF00000000000000ULL) >> 56) |\n");
    outBuffer.put("           ((val & 0x00FF000000000000ULL) >> 40) |\n");
    outBuffer.put("           ((val & 0x0000FF0000000000ULL) >> 24) |\n");
    outBuffer.put("           ((val & 0x000000FF00000000ULL) >> 8)  |\n");
    outBuffer.put("           ((val & 0x00000000FF000000ULL) << 8)  |\n");
    outBuffer.put("           ((val & 0x0000000000FF0000ULL) << 24) |\n");
    outBuffer.put("           ((val & 0x000000000000FF00ULL) << 40) |\n");
    outBuffer.put("           ((val & 0x00000000000000FFULL) << 56);\n");
    outBuffer.put("}\n\n");

    outBuffer.put("inline uint64_t extract_bits_big(const uint8_t* data, int start_bit, int length) {\n");
    outBuffer.put("    uint64_t payload = 0;\n");
    outBuffer.put("    std::memcpy(&payload, data, 8);\n");
    outBuffer.put("    payload = bswap64(payload);\n");
    outBuffer.put("    uint64_t mask = length == 64 ? ~0ULL : (1ULL << length) - 1;\n");
    outBuffer.put("    int bit_idx = (7 - (start_bit / 8)) * 8 + (start_bit % 8);\n");
    outBuffer.put("    int shift = bit_idx - length + 1;\n");
    outBuffer.put("    return (payload >> shift) & mask;\n");
    outBuffer.put("}\n\n");

    outBuffer.put("inline void insert_bits_big(uint8_t* data, uint64_t value, int start_bit, int length) {\n");
    outBuffer.put("    uint64_t payload = 0;\n");
    outBuffer.put("    std::memcpy(&payload, data, 8);\n");
    outBuffer.put("    payload = bswap64(payload);\n");
    outBuffer.put("    uint64_t mask = length == 64 ? ~0ULL : (1ULL << length) - 1;\n");
    outBuffer.put("    int bit_idx = (7 - (start_bit / 8)) * 8 + (start_bit % 8);\n");
    outBuffer.put("    int shift = bit_idx - length + 1;\n");
    outBuffer.put("    payload &= ~(mask << shift);\n");
    outBuffer.put("    payload |= (value & mask) << shift;\n");
    outBuffer.put("    payload = bswap64(payload);\n");
    outBuffer.put("    std::memcpy(data, &payload, 8);\n");
    outBuffer.put("}\n\n");
    
    foreach (msg; db.messages) {
        outBuffer.put(format("struct %s {\n", msg.name));
        
        foreach (sig; msg.signals) {
            outBuffer.put(format("    double %s; // Unit: %s\n", sig.name, sig.unit));
        }
        
        outBuffer.put("\n    void unpack(const uint8_t* data) {\n");
        foreach (sig; msg.signals) {
            string func = sig.isLittleEndian ? "extract_bits_little" : "extract_bits_big";
            outBuffer.put(format("        uint64_t raw_%s = %s(data, %d, %d);\n", 
                                 sig.name, func, sig.startBit, sig.length));
            
            if (sig.isSigned) {
                outBuffer.put(format("        int64_t signed_raw_%s = (raw_%s & (1ULL << %d)) ? (raw_%s | ~((1ULL << %d) - 1)) : raw_%s;\n",
                    sig.name, sig.name, sig.length - 1, sig.name, sig.length, sig.name));
                outBuffer.put(format("        this->%s = (signed_raw_%s * %f) + %f;\n", 
                                     sig.name, sig.name, sig.factor, sig.offset));
            } else {
                outBuffer.put(format("        this->%s = (raw_%s * %f) + %f;\n", 
                                     sig.name, sig.name, sig.factor, sig.offset));
            }
        }
        outBuffer.put("    }\n");
        
        outBuffer.put("\n    void pack(uint8_t* data) const {\n");
        foreach (sig; msg.signals) {
            if (sig.isSigned) {
                outBuffer.put(format("        int64_t raw_%s = static_cast<int64_t>((this->%s - %f) / %f);\n", 
                                     sig.name, sig.name, sig.offset, sig.factor));
            } else {
                 outBuffer.put(format("        uint64_t raw_%s = static_cast<uint64_t>((this->%s - %f) / %f);\n", 
                                     sig.name, sig.name, sig.offset, sig.factor));
            }
            
            string func = sig.isLittleEndian ? "insert_bits_little" : "insert_bits_big";
            outBuffer.put(format("        %s(data, raw_%s, %d, %d);\n", 
                                 func, sig.name, sig.startBit, sig.length));
        }
        outBuffer.put("    }\n");
        
        outBuffer.put("};\n\n");
    }
    
    outBuffer.put("} // namespace can\n");
    
    return outBuffer.data;
}