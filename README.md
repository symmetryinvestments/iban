# IBAN

![CI](https://github.com/burner/iban/workflows/ci/badge.svg)

IBAN is a package that contains functions and static data to work with
IBAN (International Bank Account Number) as well as static data about banks.

```D
IBANData[string /* ISO two digit country code */] getIBANs();
Bank[] getBanks();

/// Turns a string that follows the IBAN schema into its components
Nullable!IBAN ibanFromString(string s);

/// may not contain a valid iban member
IBAN ibanFromDetails(string isoTwoDigitCountryCode, string bankCode
		, string branchCode , string accountCode);

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
	string iban;
	string countryCode;
	string bankCode;
	string branchCode;
	string accountCode;
}

```

This package uses the data from the excellent github.com:mdomke/schwifty.git
package.

Run

```sh
dmd -run parser.d
```

to update to a new version to schwifty.
