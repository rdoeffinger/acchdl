DOCPATH=..

all: clean Dokument.pdf
	kpdf Dokument.pdf

clean:
	rm -f Dokument.pdf

%.pdf: %.tex
	TEXINPUTS=$(DOCPATH): pdflatex $<
	TEXINPUTS=$(DOCPATH): bibtex $*
	TEXINPUTS=$(DOCPATH): pdflatex $<

.PHONY: all clean
