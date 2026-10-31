import std.stdio;
import dbc.model;

void main(string[] args) {
	writeln("DBC Compiler (dbcc) initialized.");

	Database db;
	db.messages ~= Message(256, "ENGINE_STATUS", 8, "ECU", []);

	writefln("Loaded database with %d messages.", db.messages.length);
}
