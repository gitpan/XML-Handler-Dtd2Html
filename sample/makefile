
all:
	dtd2html.pl -t "Perl Package Distribution" -o ppd entry.ppd

frame:
	mkdir frame
	dtd2html.pl -f -t "Perl Package Distribution" -o frame/ppd entry.ppd

book:
	mkdir book
	dtd2html.pl -b -t "Perl Package Distrubtion" -o book/ppd -s style -x sample.ppd entry.ppd

dtd:
	dtd2html.pl -d -o out.dtd entry.ppd