import std.stdio;
import std.file;
import dbc.model;
import dbc.parser;
import dbc.cpp_gen;

void main(string[] args) {
    if (args.length < 2) {
        writeln("Usage: dbcc <input.dbc>");
        return;
    }

    string inputFile = args[1];

    if (!exists(inputFile)) {
        writefln("Error: File '%s' not found.", inputFile);
        return;
    }

    writeln("Parsing ", inputFile, "...");
    Database db = parseDbcFile(inputFile);

    writefln("Successfully parsed %d messages.", db.messages.length);
    
    writeln("Generating C++ bindings...");
    string cppCode = generateCppHeader(db);
    
    string outputFile = "generated_can.hpp";
    std.file.write(outputFile, cppCode);
    
    writefln("Done! Wrote C++ headers to %s", outputFile);
}