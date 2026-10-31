module dbc.d_gen;

import std.array;
import std.format;
import dbc.model;

string generateDModule(Database db) {
    Appender!string outBuffer;
    
    outBuffer.put("module can_messages;\n\n");
    outBuffer.put("import core.stdc.string : memcpy;\n\n");
    
    outBuffer.put("pragma(inline, true)\n");
    outBuffer.put("ulong extractBitsLittle(const ubyte* data, int startBit, int length) @nogc pure nothrow {\n");
    outBuffer.put("    ulong payload = 0;\n");
    outBuffer.put("    memcpy(&payload, data, 8);\n");
    outBuffer.put("    ulong mask = length == 64 ? ~0UL : (1UL << length) - 1;\n");
    outBuffer.put("    return (payload >> startBit) & mask;\n");
    outBuffer.put("}\n\n");
    
    outBuffer.put("pragma(inline, true)\n");
    outBuffer.put("void insertBitsLittle(ubyte* data, ulong value, int startBit, int length) @nogc pure nothrow {\n");
    outBuffer.put("    ulong payload = 0;\n");
    outBuffer.put("    memcpy(&payload, data, 8);\n");
    outBuffer.put("    ulong mask = length == 64 ? ~0UL : (1UL << length) - 1;\n");
    outBuffer.put("    payload &= ~(mask << startBit);\n");
    outBuffer.put("    payload |= (value & mask) << startBit;\n");
    outBuffer.put("    memcpy(data, &payload, 8);\n");
    outBuffer.put("}\n\n");

    outBuffer.put("pragma(inline, true)\n");
    outBuffer.put("ulong extractBitsBig(const ubyte* data, int startBit, int length) @nogc pure nothrow {\n");
    outBuffer.put("    ulong payload = 0;\n");
    outBuffer.put("    // Copy data, then byte-swap for Big Endian processing\n");
    outBuffer.put("    memcpy(&payload, data, 8);\n");
    outBuffer.put("    import core.bitop : bswap;\n");
    outBuffer.put("    payload = bswap(cast(uint)(payload >> 32)) | (cast(ulong)bswap(cast(uint)payload) << 32);\n");
    outBuffer.put("    \n");
    outBuffer.put("    ulong mask = length == 64 ? ~0UL : (1UL << length) - 1;\n");
    outBuffer.put("    // In DBC Big Endian, startBit is the MSB in a saw-tooth pattern. We map it to LSB.\n");
    outBuffer.put("    int bitIdx = (7 - (startBit / 8)) * 8 + (startBit % 8);\n");
    outBuffer.put("    int shift = bitIdx - length + 1;\n");
    outBuffer.put("    return (payload >> shift) & mask;\n");
    outBuffer.put("}\n\n");

    outBuffer.put("pragma(inline, true)\n");
    outBuffer.put("void insertBitsBig(ubyte* data, ulong value, int startBit, int length) @nogc pure nothrow {\n");
    outBuffer.put("    ulong payload = 0;\n");
    outBuffer.put("    memcpy(&payload, data, 8);\n");
    outBuffer.put("    import core.bitop : bswap;\n");
    outBuffer.put("    payload = bswap(cast(uint)(payload >> 32)) | (cast(ulong)bswap(cast(uint)payload) << 32);\n");
    outBuffer.put("    \n");
    outBuffer.put("    ulong mask = length == 64 ? ~0UL : (1UL << length) - 1;\n");
    outBuffer.put("    int bitIdx = (7 - (startBit / 8)) * 8 + (startBit % 8);\n");
    outBuffer.put("    int shift = bitIdx - length + 1;\n");
    outBuffer.put("    \n");
    outBuffer.put("    payload &= ~(mask << shift);\n");
    outBuffer.put("    payload |= (value & mask) << shift;\n");
    outBuffer.put("    \n");
    outBuffer.put("    // Byte-swap back before saving\n");
    outBuffer.put("    payload = bswap(cast(uint)(payload >> 32)) | (cast(ulong)bswap(cast(uint)payload) << 32);\n");
    outBuffer.put("    memcpy(data, &payload, 8);\n");
    outBuffer.put("}\n\n");
    
    foreach (msg; db.messages) {
        outBuffer.put(format("struct %s {\n", msg.name));
        
        foreach (sig; msg.signals) {
            outBuffer.put(format("    double %s; // Unit: %s\n", sig.name, sig.unit));
        }
        
        outBuffer.put("\n    void unpack(const ubyte* data) @nogc pure nothrow {\n");
        foreach (sig; msg.signals) {
            string func = sig.isLittleEndian ? "extractBitsLittle" : "extractBitsBig";
            outBuffer.put(format("        ulong raw_%s = %s(data, %d, %d);\n", 
                                 sig.name, func, sig.startBit, sig.length));
            
            if (sig.isSigned) {
                outBuffer.put(format("        long signed_raw_%s = (raw_%s & (1UL << %d)) ? (raw_%s | ~((1UL << %d) - 1)) : raw_%s;\n",
                    sig.name, sig.name, sig.length - 1, sig.name, sig.length, sig.name));
                outBuffer.put(format("        this.%s = (signed_raw_%s * %f) + %f;\n", 
                                     sig.name, sig.name, sig.factor, sig.offset));
            } else {
                outBuffer.put(format("        this.%s = (raw_%s * %f) + %f;\n", 
                                     sig.name, sig.name, sig.factor, sig.offset));
            }
        }
        outBuffer.put("    }\n");
        
        outBuffer.put("\n    void pack(ubyte* data) const @nogc pure nothrow {\n");
        foreach (sig; msg.signals) {
            if (sig.isSigned) {
                outBuffer.put(format("        long raw_%s = cast(long)((this.%s - %f) / %f);\n", 
                                     sig.name, sig.name, sig.offset, sig.factor));
            } else {
                 outBuffer.put(format("        ulong raw_%s = cast(ulong)((this.%s - %f) / %f);\n", 
                                     sig.name, sig.name, sig.offset, sig.factor));
            }
            
            string func = sig.isLittleEndian ? "insertBitsLittle" : "insertBitsBig";
            outBuffer.put(format("        %s(data, raw_%s, %d, %d);\n", 
                                 func, sig.name, sig.startBit, sig.length));
        }
        outBuffer.put("    }\n");
        
        outBuffer.put("}\n\n");
    }
    
    return outBuffer.data;
}