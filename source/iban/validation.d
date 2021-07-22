module iban.validation;

import std.array : array, empty;
import std.algorithm.iteration : joiner, map;
import std.algorithm.searching : all, startsWith;
import std.ascii : isAlpha, isAlphaNum, isUpper;
import std.conv : to;
import std.range : takeExactly;
import std.typecons : Nullable, nullable;
import std.uni : isNumber;
import std.utf : byChar;
import std.stdio;
import std.format;

import iban.ibans;
import iban.structures;

@safe:

string removeWhite(string input) {
	import std.array : replace;
	return input.replace(" ", "");
}

Nullable!string extractCountryPrefix(string input) {
	import std.ascii : isUpper;
	return input.length > 1
			&& input[0].isUpper()
			&& input[1].isUpper()
		? nullable(input[0 .. 2])
		: Nullable!(string).init;
}

bool isValidIBAN(string toTest) {
	Nullable!string specKey = extractCountryPrefix(toTest);

	if(specKey.isNull()) {
		return false;
	}

	auto spec = specKey.get() in getIBANs();

	if(spec is null) {
		return false;
	}

	return isValidIBAN(toTest, *spec);
}

bool isValidIBAN(string toTest, IBANData spec) {
	toTest = toTest.removeWhite();

	return validateLength(spec, toTest)
		&& validateCharacters(toTest)
		&& validateFormat(spec, toTest)
		&& validateChecksum(toTest);
}

bool validateCharacters(string toTest) {
	import std.regex : regex, matchFirst;
	import std.algorithm.searching : startsWith;
	auto re = regex(`[A-Z]{2}\d{2}[A-Z]*`);
	auto m = matchFirst(toTest, re);
	return m.length == 1 && toTest.startsWith(m[0]);
}

unittest {
	import iban.testdata;
	foreach(it; valid) {
		string pp = it.removeWhite();
		assert(pp.validateCharacters(), it);
		assert(pp.validateLength(), it);
		assert(pp.validateFormat(), it);
		assert(pp.validateChecksum(), it);
	}
}

unittest {
	import iban.testdata;
	foreach(it; invalid) {
		string pp = it.removeWhite();
		assert(pp.validateCharacters()
			|| pp.validateLength()
			|| pp.validateFormat()
			|| pp.validateChecksum(), it);
	}
}

bool validateLength(string iban) {
	import std.typecons : Nullable;
	Nullable!string specKey = extractCountryPrefix(iban);

	if(specKey.isNull()) {
		return false;
	}

	auto spec = specKey.get() in getIBANs();
	return spec !is null && validateLength(*spec, iban);
}

bool validateLength(IBANData spec, string iban) {
	return iban.length == spec.ibanLength;
}

bool matchDirect(string iban, Parse p) {
	return iban.startsWith(p.direct);
}

bool matchSpaces(string iban, Parse p) {
	return iban.length >= p.number
		&& iban.byChar.map!(it => ' ')
			.takeExactly(p.number)
			.all;
}

bool matchNumber(string iban, Parse p) {
	bool ret = iban.length >= p.number
		&& iban.byChar
			.map!(it => isNumber(it))
			.takeExactly(p.number)
			.all;

	return ret;
}

bool matchAlpha(string iban, Parse p) {
	return iban.length >= p.number
		&& iban.byChar.map!(it => isAlpha(it) && isUpper(it))
			.takeExactly(p.number)
			.all;
}

bool matchAlphaNum(string iban, Parse p) {
	return iban.length >= p.number
		&& iban.byChar
			.map!(it => isAlphaNum(it))
			.takeExactly(p.number)
			.all;
}

struct MatchResult {
	bool matches;
	string cutString;
}

MatchResult match(string iban, Parse p) {
	MatchResult ret;
	final switch(p.type) {
		case ParseType.direct:
			ret.matches = matchDirect(iban, p);
			break;
		case ParseType.number:
			ret.matches = matchNumber(iban, p);
			break;
		case ParseType.alpha:
			ret.matches = matchAlpha(iban, p);
			break;
		case ParseType.alphanum:
			ret.matches = matchAlphaNum(iban, p);
			break;
		case ParseType.space:
			ret.matches = matchSpaces(iban, p);
			break;
	}
	ret.cutString = iban.length >= p.number
		? iban[p.number .. $]
		: iban;

	return ret;
}

bool validateFormat(string iban) {
	Nullable!string specKey = extractCountryPrefix(iban);

	if(specKey.isNull()) {
		return false;
	}

	auto spec = specKey.get() in getIBANs();
	return spec !is null && validateFormat(*spec, iban);
}

bool validateFormat(IBANData spec, string iban) {
	string tmp = iban;
	foreach(idx, it; spec.ibanSpecRegex) {
		MatchResult ne = match(tmp, it);
		if(!ne.matches) {
			return false;
		}
		tmp = ne.cutString;
	}
	return tmp.empty;
}

bool validateChecksum(string iban) {
	import std.bigint;

	if(iban.length <= 4) {
		return false;
	}

	long chkSum = to!long(iban[2 .. 4]);

	// The bank number + account number
	string bban = iban[4 .. $]
		.map!(it => it >= 'A'
				? to!string(to!int(it - 'A' + 10))
				: to!string(it)
		)
		.joiner("")
		.to!string();

	// the prefix to postfix conversion for the checksum check
	string prefix = iban[0 .. 4]
		.map!(it => it >= 'A'
				? to!int(it - 'A' + 10)
				: 0
		)
		.map!(it => to!string(it))
		.joiner("")
		.to!string();

	// the prefix to postfix conversion for % 97 == 1 check
	string prefix2 = iban[0 .. 4]
		.map!(it => it >= 'A'
				? to!int(it - 'A' + 10)
				: to!int(it - '0')
		)
		.map!(it => to!string(it))
		.joiner("")
		.to!string();

	string cc = bban ~ prefix;
	BigInt num = cc;
	long mod = num % 97;
	long chkSumTT = 98 - mod;

	string cc2 = bban ~ prefix2;
	BigInt num2 = cc2;
	long mod2 = num2 % 97;

	return chkSumTT == chkSum && mod2 == 1;
}
