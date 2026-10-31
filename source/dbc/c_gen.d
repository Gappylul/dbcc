module dbc.c_gen;

import std.array;
import std.format;
import std.string;
import dbc.model;

string generateCHeader(Database db) {
    Appender!string outBuffer;
    
    outBuffer.put("#ifndef CAN_MESSAGES_H\n");
    outBuffer.put("#define CAN_MESSAGES_H\n\n");
    
    outBuffer.put("#include <stdint.h>\n");
    outBuffer.put("#include <string.h>\n\n");
    
    outBuffer.put("static inline uint64_t can_extract_bits_little(const uint8_t* data, int start_bit, int length) {\n");
    outBuffer.put("    uint64_t payload = 0;\n");
    outBuffer.put("    memcpy(&payload, data, 8);\n");
    outBuffer.put("    uint64_t mask = length == 64 ? ~0ULL : (1ULL << length) - 1;\n");
    outBuffer.put("    return (payload >> start_bit) & mask;\n");
    outBuffer.put("}\n\n");
    
    outBuffer.put("static inline void can_insert_bits_little(uint8_t* data, uint64_t value, int start_bit, int length) {\n");
    outBuffer.put("    uint64_t payload = 0;\n");
    outBuffer.put("    memcpy(&payload, data, 8);\n");
    outBuffer.put("    uint64_t mask = length == 64 ? ~0ULL : (1ULL << length) - 1;\n");
    outBuffer.put("    payload &= ~(mask << start_bit);\n");
    outBuffer.put("    payload |= (value & mask) << start_bit;\n");
    outBuffer.put("    memcpy(data, &payload, 8);\n");
    outBuffer.put("}\n\n");

    outBuffer.put("static inline uint64_t can_bswap64(uint64_t val) {\n");
    outBuffer.put("    return ((val & 0xFF00000000000000ULL) >> 56) |\n");
    outBuffer.put("           ((val & 0x00FF000000000000ULL) >> 40) |\n");
    outBuffer.put("           ((val & 0x0000FF0000000000ULL) >> 24) |\n");
    outBuffer.put("           ((val & 0x000000FF00000000ULL) >> 8)  |\n");
    outBuffer.put("           ((val & 0x00000000FF000000ULL) << 8)  |\n");
    outBuffer.put("           ((val & 0x0000000000FF0000ULL) << 24) |\n");
    outBuffer.put("           ((val & 0x000000000000FF00ULL) << 40) |\n");
    outBuffer.put("           ((val & 0x00000000000000FFULL) << 56);\n");
    outBuffer.put("}\n\n");

    outBuffer.put("static inline uint64_t can_extract_bits_big(const uint8_t* data, int start_bit, int length) {\n");
    outBuffer.put("    uint64_t payload = 0;\n");
    outBuffer.put("    memcpy(&payload, data, 8);\n");
    outBuffer.put("    payload = can_bswap64(payload);\n");
    outBuffer.put("    uint64_t mask = length == 64 ? ~0ULL : (1ULL << length) - 1;\n");
    outBuffer.put("    int bit_idx = (7 - (start_bit / 8)) * 8 + (start_bit % 8);\n");
    outBuffer.put("    int shift = bit_idx - length + 1;\n");
    outBuffer.put("    return (payload >> shift) & mask;\n");
    outBuffer.put("}\n\n");

    outBuffer.put("static inline void can_insert_bits_big(uint8_t* data, uint64_t value, int start_bit, int length) {\n");
    outBuffer.put("    uint64_t payload = 0;\n");
    outBuffer.put("    memcpy(&payload, data, 8);\n");
    outBuffer.put("    payload = can_bswap64(payload);\n");
    outBuffer.put("    uint64_t mask = length == 64 ? ~0ULL : (1ULL << length) - 1;\n");
    outBuffer.put("    int bit_idx = (7 - (start_bit / 8)) * 8 + (start_bit % 8);\n");
    outBuffer.put("    int shift = bit_idx - length + 1;\n");
    outBuffer.put("    payload &= ~(mask << shift);\n");
    outBuffer.put("    payload |= (value & mask) << shift;\n");
    outBuffer.put("    payload = can_bswap64(payload);\n");
    outBuffer.put("    memcpy(data, &payload, 8);\n");
    outBuffer.put("}\n\n");

    foreach (msg; db.messages) {
        outBuffer.put(format("typedef struct {\n"));
        foreach (sig; msg.signals) {
            outBuffer.put(format("    double %s; // Unit: %s\n", sig.name, sig.unit));
        }
        outBuffer.put(format("} can_%s_t;\n\n", msg.name.toLower()));
    }

    foreach (msg; db.messages) {
        string structName = format("can_%s_t", msg.name.toLower());
        
        outBuffer.put(format("static inline void unpack_%s(%s* msg, const uint8_t* data) {\n", msg.name.toLower(), structName));
        
        foreach (sig; msg.signals) {
            string func = sig.isLittleEndian ? "can_extract_bits_little" : "can_extract_bits_big";
            outBuffer.put(format("    uint64_t raw_%s = %s(data, %d, %d);\n", 
                                 sig.name, func, sig.startBit, sig.length));
            
            if (sig.isSigned) {
                outBuffer.put(format("    int64_t signed_raw_%s = (raw_%s & (1ULL << %d)) ? (raw_%s | ~((1ULL << %d) - 1)) : raw_%s;\n",
                    sig.name, sig.name, sig.length - 1, sig.name, sig.length, sig.name));
                outBuffer.put(format("    msg->%s = (signed_raw_%s * %f) + %f;\n", 
                                     sig.name, sig.name, sig.factor, sig.offset));
            } else {
                outBuffer.put(format("    msg->%s = (raw_%s * %f) + %f;\n", 
                                     sig.name, sig.name, sig.factor, sig.offset));
            }
        }
        outBuffer.put("}\n\n");
    }

    foreach (msg; db.messages) {
        string structName = format("can_%s_t", msg.name.toLower());
        
        outBuffer.put(format("static inline void pack_%s(const %s* msg, uint8_t* data) {\n", msg.name.toLower(), structName));
        
        foreach (sig; msg.signals) {
            if (sig.isSigned) {
                outBuffer.put(format("    int64_t raw_%s = (int64_t)((msg->%s - %f) / %f);\n", 
                                     sig.name, sig.name, sig.offset, sig.factor));
            } else {
                 outBuffer.put(format("    uint64_t raw_%s = (uint64_t)((msg->%s - %f) / %f);\n", 
                                     sig.name, sig.name, sig.offset, sig.factor));
            }
            
            string func = sig.isLittleEndian ? "can_insert_bits_little" : "can_insert_bits_big";
            outBuffer.put(format("    %s(data, raw_%s, %d, %d);\n", 
                                 func, sig.name, sig.startBit, sig.length));
        }
        outBuffer.put("}\n\n");
    }
    
    outBuffer.put("#endif // CAN_MESSAGES_H\n");
    
    return outBuffer.data;
}