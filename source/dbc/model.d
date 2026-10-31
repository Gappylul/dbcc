module dbc.model;

// Represents a single piece of data inside a CAN frame
struct Signal {
    string name;
    int length;
    bool isLittleEndian;
    bool isSigned;
    double factor;
    double offset;
    double min;
    double max;
    string unit;
    string receiver; // Which node is expected to read this
}

// Represents a full CAN frame (8 bytes) containing multiple signals
struct Message {
    uint id;
    string name;
    uint dlc; // Data Length Code (number of bytes)
    string senderNode;
    Signal[] signals;
}

// Represents the full .dbc file
struct Database {
    Message[] messages;
}