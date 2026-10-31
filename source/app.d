import std.stdio;
import std.file;
import std.getopt;
import dbc.model;
import dbc.parser;
import dbc.cpp_gen;
import dbc.d_gen;
import dbc.c_gen;

void main(string[] args) {
    string lang = "cpp";
    string outputFile = "";

    auto helpInformation = getopt(
        args,
        "lang|l", "Target language (c, cpp, d)", &lang,
        "out|o", "Output file name", &outputFile
    );

    if (helpInformation.helpWanted || args.length < 2) {
        defaultGetoptPrinter("Usage: dbcc [options] <input.dbc>", helpInformation.options);
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
    
    if (lang == "cpp") {
        writeln("Generating C++ bindings...");
        string cppCode = generateCppHeader(db);
        if (outputFile == "") outputFile = "generated_can.hpp";
        std.file.write(outputFile, cppCode);
    } 
    else if (lang == "d") {
        writeln("Generating D bindings...");
        string dCode = generateDModule(db);
        if (outputFile == "") outputFile = "can_messages.d";
        std.file.write(outputFile, dCode);
    }
    else if (lang == "c") {
        writeln("Generating C bindings...");
        string cCode = generateCHeader(db);
        if (outputFile == "") outputFile = "generated_can.h";
        std.file.write(outputFile, cCode);
    }
    else {
        writefln("Error: Unsupported language '%s'. Use 'c', 'cpp', or 'd'.", lang);
        return;
    }
    
    writefln("Done! Wrote code to %s", outputFile);
}