import std;

struct Bank {
	string country_code;
	bool primary;
	string bic;
	string bank_code;
	Nullable!string checksum_algo;
	string name;
	string short_name;
}

string nullToString(T)(Nullable!T n) {
	string ret;
	static if(is(T == string)) {
		ret = n.isNull()
			? format("Nullable!(%s).init", T.stringof)
			: format("Nullable!(%s)(\"%s\")", T.stringof, n.get());
	} else {
		ret = n.isNull()
			? format("Nullable!(%s).init", T.stringof)
			: format("Nullable!(%s)(%s)", T.stringof, n.get());
	}
	return ret;
}

string toString(T)(T that) {
	string ret = T.stringof ~ "(";
	bool first = true;
	foreach(mem; __traits(allMembers, T)) {
		static if(mem != "toString" && mem != "opAssign") {{
			if(!first) {
				ret ~= ", ";
			}
			first = false;

			static if(is(typeof(__traits(getMember, that, mem)) : Nullable!F, F)) {{
				ret ~= nullToString(__traits(getMember, that, mem));
			}} else static if(is(typeof(__traits(getMember, that, mem)) == string)) {{
				ret ~= format("\"%s\"", __traits(getMember, that, mem)
						.replace("\"", `\"`));
			}} else static if(is(typeof(__traits(getMember, that, mem)) == enum)) {{
				ret ~= format("ParseType.%s", __traits(getMember, that, mem));
			}} else static if(is(typeof(__traits(getMember, that, mem)) == Parse[])) {{
				ret ~= format("[%--(%s,%)]", __traits(getMember, that, mem)
						.map!(it => toString!Parse(it)));
			}} else {{
				ret ~= format("%s", __traits(getMember, that, mem));
			}}
		}}
	}
	ret ~= ")";
	return ret;
}

string[] bankKeys = [ __traits(allMembers, Bank) ];

Bank parseBank(JSONValue jv) {
	Bank ret;
	foreach(mem; __traits(allMembers, Bank)) {{
		static if(mem != "opAssign") {
			try {
				alias MT = typeof(__traits(getMember, Bank, mem));
				static if(is(MT : Nullable!F, F)) {{
					if(mem in jv) {
						__traits(getMember, ret, mem) = jv[mem].get!F();
					}
				}} else {{
					__traits(getMember, ret, mem) = jv[mem].get!MT();
				}}
			} catch(Exception e) {
				assert(false, format("%s\n%s\n%s", mem, jv.toPrettyString()
					, e.toString()));
			}
		}
	}}
	foreach(key; jv.objectNoRef().keys()) {
		assert(canFind(bankKeys, key)
				, format("%s\n%s", key, jv.toPrettyString())
			);
	}

	return ret;
}

Bank[] parseBanks(JSONValue jv) {
	return jv.arrayNoRef().map!(it => parseBank(it)).array;
}

Bank[] parseBanks(string fn) {
	return parseBanks(readText(fn).parseJSON());
}

Bank[] parseBanks() {
	return dirEntries("schwifty/schwifty/bank_registry/", "*.json"
			, SpanMode.shallow)
		.map!(it => it.name)
		.map!(it => parseBanks(it))
		.joiner
		.array;
}

string[] ibanKeys = [ __traits(allMembers, IBANData) ];

struct IBANDataParse {
	string country_key;
	string bban_spec;
	string iban_spec;
	long bban_length;
	long iban_length;
	long[][string] positions;
}

// _spec_to_re: Dict[str, str] = {"n": r"\d", "a": r"[A-Z]", "c": r"[A-Za-z0-9]", "e": r" "}

enum ParseType {
	direct,
	number,
	alpha,
	alphanum,
	space
}

ParseType toParseType(char c) {
	switch(c) {
		case 'd': return ParseType.direct;
		case 'n': return ParseType.number;
		case 'a': return ParseType.alpha;
		case 'c': return ParseType.alphanum;
		case 'e': return ParseType.space;
		default: assert(false, format("'%s'", c));
	}
	assert(false, format("Unhandled '%s'", c));
}

struct Parse {
	ParseType type;
	string direct;
	long number;
}

// "AD2!n4!n4!n12!c"

Parse[] parseRegex(string input) {
	import std.uni : isNumber;
	Parse[] ret;
	string cur;
	for(int i = 0; i < input.length; ) {
		long j = i;
		if(isNumber(input[i])) {
			if(!cur.empty) {
				ret ~= Parse(ParseType.direct, cur, cur.length);
			}
			cur = "";

			Parse tmp;

			// eat the number
			string num;
			for(; i < input.length && isNumber(input[i]); ++i) {
				num ~= input[i];
			}

			tmp.number = num.empty
				? 1
				: to!long(num);

			// eat the '!'
			assert(i < input.length);
			assert(input[i] == '!', input[i .. $]);
			++i;

			// eat the [d,n,a,c,e]
			tmp.type = toParseType(input[i]);
			++i;

			tmp.direct = input[j .. i];
			ret ~= tmp;
		} else {
			cur ~= input[i];
			++i;
		}
	}
	if(!cur.empty) {
		ret ~= Parse(ParseType.direct, cur, 0);
	}
	return ret;
}

struct IBANData {
	string country_key;
	string bban_spec;
	string iban_spec;
	long bban_length;
	long iban_length;
	long[][string] positions;
	Parse[] bban_spec_regex;
	Parse[] iban_spec_regex;
}

IBANData toIBANData(IBANDataParse old) {
	IBANData ret;
	foreach(mem; __traits(allMembers, IBANDataParse)) {{
		static if(mem != "opAssign" && mem != "country_key") {
			__traits(getMember, ret, mem) = __traits(getMember, old, mem);
		}
	}}
	ret.bban_spec_regex = parseRegex(ret.bban_spec);
	ret.iban_spec_regex = parseRegex(ret.iban_spec);
	return ret;
}

IBANDataParse parseIBAN(string ck, JSONValue jv) {
	IBANDataParse ret;
	ret.country_key = ck;
	foreach(mem; __traits(allMembers, IBANDataParse)) {{
		static if(mem != "opAssign" && mem != "country_key") {
			try {
				alias MT = typeof(__traits(getMember, IBANDataParse, mem));
				static if(is(MT : Nullable!F, F)) {{
					if(mem in jv) {
						__traits(getMember, ret, mem) = jv[mem].get!F();
					}
				}} else static if(is(MT T == T[U], U : string)) {{
					foreach(key, value; jv[mem].objectNoRef()) {
						__traits(getMember, ret, mem)[key] = value.arrayNoRef
							.map!(it => it.get!long)
							.array;
					}
				}} else {{
					__traits(getMember, ret, mem) = jv[mem].get!MT();
				}}
			} catch(Exception e) {
				assert(false, format("%s\n%s\n%s", mem, jv.toPrettyString()
					, e.toString()));
			}
		}
	}}
	foreach(key; jv.objectNoRef().keys()) {
		assert(canFind(ibanKeys, key)
				, format("%s\n%s", key, jv.toPrettyString())
			);
	}
	return ret;
}

IBANDataParse[string] parseIBAN() {
	IBANDataParse[string] ret;
	foreach(key, value;
			readText("schwifty/schwifty/iban_registry/generated.json")
			.parseJSON().objectNoRef())
	{
		ret[key] = parseIBAN(key, value);
	}
	return ret;
}

void main() {
	{
		auto f = File("source/iban/banks.d", "w");
		f.writeln("module iban.banks;\n");
		f.writeln("import std.typecons : Nullable;\n");
		f.writeln("import iban.structures;\n");
		f.writeln("Bank[] getBanks() @safe {");
		f.writeln("\tstatic bool hasBeenInited = false;");
		f.writeln("\tstatic Bank[] ret;");
		f.writeln("\tif(!hasBeenInited) {");
		foreach(b; parseBanks()) {
			f.writefln("\t\tret ~= %s;", toString!Bank(b));
		}
		f.writeln("\t\thasBeenInited = true;");
		f.writeln("\t}");
		f.writeln("\treturn ret;");
		f.writeln("}");
	}

	{
		auto f = File("source/iban/ibans.d", "w");
		f.writeln("module iban.ibans;\n");
		f.writeln("import iban.structures;\n");
		f.writeln("IBANData[string] getIBANs() @safe {");
		f.writeln("\tstatic bool hasBeenInited = false;");
		f.writeln("\tstatic IBANData[string] ret;");
		f.writeln("\tif(!hasBeenInited) {");
		foreach(b; parseIBAN()) {
			IBANData updated = toIBANData(b);
			f.writefln("\t\tret[\"%s\"] = %s;", b.country_key
					, toString!IBANData(updated));
		}
		f.writeln("\t\thasBeenInited = true;");
		f.writeln("\t}");
		f.writeln("\treturn ret;");
		f.writeln("}");
	}
}
