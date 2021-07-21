DF=-I=source -unittest -g -cov
ut: banks.o iban.o structures.o testdata.o validation.o constructor.o
	dmd -main -unittest -g -cov banks.o iban.o structures.o testdata.o validation.o constructor.o -of=ut

banks.o: source/iban/banks.d source/iban/structures.d
	dmd -c source/iban/banks.d ${DF}  -of=$@

iban.o: source/iban/iban.d source/iban/structures.d
	dmd -c source/iban/iban.d ${DF} -of=$@

structures.o: source/iban/structures.d
	dmd -c source/iban/structures.d ${DF} -of=$@

testdata.o: source/iban/testdata.d
	dmd -c source/iban/testdata.d ${DF} -of=$@

validation.o: source/iban/validation.d source/iban/structures.d source/iban/testdata.d source/iban/iban.d
	dmd -c source/iban/validation.d ${DF} -of=$@

constructor.o: source/iban/constructor.d source/iban/validation.d source/iban/testdata.d source/iban/structures.d source/iban/iban.d
	dmd -c source/iban/constructor.d ${DF} -of=$@

clean:
	rm ut *.o
