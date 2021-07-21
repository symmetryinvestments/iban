module iban.structures;

import std.typecons : Nullable;

@safe:

struct Bank {
	string countryCode;
	bool primary;
	string bic;
	string bankCode;
	Nullable!string checksumAlgo;
	string name;
	string shortName;
}

enum ParseType {
	direct,
	number,
	alpha,
	alphanum,
	space
}

struct Parse {
	ParseType type;
	string direct;
	long number;
}

struct IBANData {
	string countryKey;
	string bbanSpec;
	string ibanSpec;
	long bbanLength;
	long ibanLength;
	long[][string] positions;
	Parse[] bbanSpecRegex;
	Parse[] ibanSpecRegex;
}

struct IBAN {
	// WARNING if the iban is computed do not transfer funds to it
	// double check with the bank
	string iban;
	string countryCode;
	string bankCode;
	string branchCode;
	string accountCode;
}
