CFLAGS=-O2 -g3 -W -Wall

%: %.c
	gcc $(CFLAGS) -o $@ $<

%.pdf: %.tex
	pdflatex $<

clean:
	rm -f *.aux *.log *.pdf

doc:
	make -C cappstyle

