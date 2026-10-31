module dbc.parser;

import std.stdio;
import std.file;
import std.regex;
import std.conv;
import std.string;
import dbc.model;

Database parseDbcFile(string filePath) {
    Database db;
    string content = readText(filePath);

    // Regex for Message: BO_ 256 ENGINE_DATA: 8 EngineNode
    auto boRegex = ctRegex!`BO_\s+(\d+)\s+(\w+):\s+(\d+)\s+(\w+)`;

    // Regex for Signal: SG_ EngineSpeed : 24|16@1+ (0.25,0) [0|8000] "rpm" ReceiverNode
    auto sgRegex = ctRegex!`SG_\s+(\w+)\s*:\s*(\d+)\|(\d+)
        @([01])([+-])\s*\(([0-9.-]+),([0-9.-]+)\)\s*\[([0-9.-]+)\|([0-9.-]+)\]\s*"([^"]*)"\s*(.*)`;

    Message* currentMsg = null;

    foreach (line; content.splitLines()) {
        line = line.strip();

        if (auto mMatch = matchFirst(line, boRegex)) {
            Message msg = {
                id: mMatch[1].to!uint,
                name: mMatch[2],
                dlc: mMatch[3].to!uint,
                senderNode: mMatch[4]
            };
            db.messages ~= msg;
            currentMsg = &db.messages[$ - 1];
        }
        else if (auto sMatch = matchFirst(line, sgRegex)) {
            if (currentMsg !is null) {
                Signal sig = {
                    name: sMatch[1],
                    startBit: sMatch[2].to!int,
                    length: sMatch[3].to!int,
                    isLittleEndian: (sMatch[4] == "1"),
                    isSigned: (sMatch[5] == "-"),
                    factor: sMatch[6].to!double,
                    offset: sMatch[7].to!double,
                    min: sMatch[8].to!double,
                    max: sMatch[9].to!double,
                    unit: sMatch[10],
                    receiver: sMatch[11].strip()
                };
                currentMsg.signals ~= sig;
            }
        }
    }
    return db;
}