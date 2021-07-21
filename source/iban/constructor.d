module iban.constructor;

import std.typecons : Nullable, nullable;
import std.format : format;
import std.stdio;

import iban.validation;
import iban.structures;
import iban.iban;

@safe:

Nullable!IBAN ibanFromString(string s) {
	s = removeWhite(s);
	Nullable!string specKey = extractCountryPrefix(s);

	if(specKey.isNull()) {
		return Nullable!(IBAN).init;
	}

	auto spec = specKey.get() in getIBANs();

	if(spec is null) {
		return Nullable!(IBAN).init;
	}

	if(!isValidIBAN(s, *spec)) {
		return Nullable!(IBAN).init;
	}

	if(s.length < 4) {
		return Nullable!(IBAN).init;
	}

	IBAN ret;
	ret.countryCode = s[0 .. 2];
	s = s[4 .. $];
	static foreach(it;
			[ [ "accountCode", "account_code" ]
			, [ "bankCode", "bank_code" ]
			, [ "branchCode", "branch_code" ]
			])
	{{
		long[]* pos = it[1] in spec.positions;
		if(pos !is null && (*pos).length > 1) {
			long[] ppos = *pos;
			ulong left = ppos[0];
			ulong right = ppos[1];
			if(left > s.length) {
				return Nullable!(IBAN).init;
			}
			if(right > s.length) {
				return Nullable!(IBAN).init;
			}
			__traits(getMember, ret, it[0]) = s[left .. right];
		}
	}}

	return nullable(ret);
}

unittest {
	import iban.testdata;

	foreach(it; valid) {
		Nullable!IBAN t = ibanFromString(it);
		assert(!t.isNull(), it);
	}
}

unittest {
	import iban.testdata;

	foreach(it; invalid) {
		Nullable!IBAN t = ibanFromString(it);
		assert(t.isNull(), it);
	}
}

Nullable!string buildIBANFromParts(string isoTwoDigitCountryCode, string bankCode
		, string branchCode , string accountCode)
{
	import std.algorithm.iteration : map, joiner;
	import std.bigint;
	import std.conv : to;

	auto spec = isoTwoDigitCountryCode in getIBANs();

	if(spec is null) {
		return Nullable!(string).init;
	}

	char[] tmp = new char[](spec.bbanLength);
	tmp[] = '0';

	// The three parts of the IBAN according to the countries spec
	static foreach(it;
			[ [ "accountCode", "account_code" ]
			, [ "bankCode", "bank_code" ]
			, [ "branchCode", "branch_code" ]
			])
	{{
		long[]* pos = it[1] in spec.positions;
		if(pos !is null && (*pos).length > 1) {
			long[] ppos = *pos;
			ulong left = ppos[0];
			ulong right = ppos[1];
			if(left > tmp.length) {
				return Nullable!(string).init;
			}
			if(right > tmp.length) {
				return Nullable!(string).init;
			}
			mixin(format("tmp[left .. right] = %s;\n", it[0]));
		}
	}}

	// Computing the checksum

	string bban = tmp
		.map!(it => it >= 'A'
				? to!string(to!int(it - 'A' + 10))
				: to!string(it)
		)
		.joiner("")
		.to!string();

	string prefix = isoTwoDigitCountryCode
		.map!(it => it >= 'A'
				? to!int(it - 'A' + 10)
				: 0
		)
		.map!(it => to!string(it))
		.joiner("")
		.to!string();

	string cc = bban ~ prefix ~ "00";
	BigInt num = cc;
	long mod = num % 97;
	long chkSumTT = 98 - mod;

	string ret = isoTwoDigitCountryCode ~ format("%02d", chkSumTT)
		~ tmp.to!string();

	return nullable(ret);
}

IBAN ibanFromDetails(string isoTwoDigitCountryCode, string bankCode
		, string branchCode , string accountCode)
{
	IBAN ret;
	ret.countryCode = isoTwoDigitCountryCode;
	ret.bankCode = bankCode;
	ret.branchCode = branchCode;
	ret.accountCode = accountCode;

	Nullable!string data = buildIBANFromParts(isoTwoDigitCountryCode, bankCode
			, branchCode, accountCode);
	if(!data.isNull()) {
		ret.iban = data.get();
	}

	return ret;
}

unittest {
	import iban.testdata;

	foreach(it; valid) {
		it = it.removeWhite();
		Nullable!IBAN t = ibanFromString(it);
		assert(!t.isNull(), it);
		IBAN tNN = t.get();
		auto r = buildIBANFromParts(tNN.countryCode, tNN.bankCode
				, tNN.branchCode, tNN.accountCode);
		assert(!r.isNull());
		auto rNN = r.get();
		if(rNN != it) {
			writefln("\nexp: %s\ngot: %s", it, rNN);
		}
	}
}
