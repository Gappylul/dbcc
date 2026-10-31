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
    
    outBuffer.put("inline uint64_t extract_bits(const uint8_t* data, int start_bit, int length) {\n");
    outBuffer.put("    uint64_t payload = 0;\n");
    outBuffer.put("    std::memcpy(&payload, data, 8); // Assuming 8-byte CAN frame\n");
    outBuffer.put("    uint64_t mask = length == 64 ? ~0ULL : (1ULL << length) - 1;\n");
    outBuffer.put("    return (payload >> start_bit) & mask;\n");
    outBuffer.put("}\n\n");

    foreach (msg; db.messages) {
        outBuffer.put(format("struct %s {\n", msg.name));

        foreach (sig; msg.signals) {
            outBuffer.put(format("    double %s; // Unit: %s\n", sig.name, sig.unit));
        }

        outBuffer.put("\n    void unpack(const uint8_t* data) {\n");
        foreach (sig; msg.signals) {
            outBuffer.put(format("        uint64_t raw_%s = extract_bits(data, %d, %d);\n", 
                                 sig.name, sig.startBit, sig.length));
            
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
        outBuffer.put("};\n\n");
    }
    
    outBuffer.put("} // namespace can\n");
    
    return outBuffer.data;
}