import std.stdio;
import std.file;
import dbc.model;
import dbc.parser;

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
    
    foreach (msg; db.messages) {
        writefln("- Message: %s (ID: %d, DLC: %d bytes)", msg.name, msg.id, msg.dlc);
        foreach (sig; msg.signals) {
            writefln("  -> Signal: %s (Start: %d, Length: %d, Unit: %s)", 
                     sig.name, sig.startBit, sig.length, sig.unit);
        }
    }
}
