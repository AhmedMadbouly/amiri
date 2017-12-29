.PHONY: all clean ttf web pack check

NAME=amiri
VERSION=0.111

TOOLS=tools
SRC=sources
WEB=webfonts
DOC=documentation
TESTS=test-suite
FONTS=$(NAME)-regular $(NAME)-bold $(NAME)-slanted $(NAME)-boldslanted $(NAME)-quran $(NAME)-quran-colored
DIST=$(NAME)-$(VERSION)
WDIST=$(NAME)-$(VERSION)-webfonts

BUILD=$(TOOLS)/build.py
RUNTEST=$(TOOLS)/runtest.py
MAKECLR=$(TOOLS)/makeclr.py
MAKECSS=$(TOOLS)/makecss.py
MAKEWEB=$(TOOLS)/makeweb.py
PY ?= python3
PY2 ?= python2
FF=$(PY2) $(BUILD)
PP=gpp -I$(SRC)

SFDS=$(FONTS:%=$(SRC)/%.sfdir)
DTTF=$(FONTS:%=%.ttf)
WOFF=$(FONTS:%=$(WEB)/%.woff)
WOF2=$(FONTS:%=$(WEB)/%.woff2)
CSSS=$(WEB)/$(NAME).css
PDFS=$(DOC)/$(NAME)-table.pdf $(DOC)/$(NAME)-quran-table.pdf $(DOC)/documentation-arabic.pdf
FEAT=$(wildcard $(SRC)/*.fea)
TEST=$(wildcard $(TESTS)/*.test)
TEST+=$(wildcard $(TESTS)/*.ptest)

all: ttf web

ttf: $(DTTF)
web: $(WOFF) $(WOF2) $(CSSS)
doc: $(PDFS)

$(NAME)-quran.ttf: $(SRC)/$(NAME)-regular.sfdir $(SRC)/latin/amirilatin-regular.sfdir $(SRC)/$(NAME).fea $(FEAT) $(BUILD)
	@echo "   FF	$@"
	@$(PP) -DQURAN $(SRC)/$(NAME).fea -o $(SRC)/$(NAME)-quran.fea.pp
	@$(FF) --input $< --output $@ --features=$(SRC)/$(NAME)-quran.fea.pp --version $(VERSION) --quran

$(NAME)-quran-colored.ttf: $(NAME)-quran.ttf $(MAKECLR)
	@echo "   FF	$@"
	@$(PY) $(MAKECLR) $< $@

$(NAME)-regular.ttf: $(SRC)/$(NAME)-regular.sfdir $(SRC)/latin/amirilatin-regular.sfdir $(SRC)/$(NAME).fea $(FEAT) $(BUILD)
	@echo "   FF	$@"
	@$(PP) $(SRC)/$(NAME).fea -o $(SRC)/$(NAME)-regular.fea.pp
	@$(FF) --input $< --output $@ --features=$(SRC)/$(NAME)-regular.fea.pp --version $(VERSION)

$(NAME)-slanted.ttf: $(SRC)/$(NAME)-regular.sfdir $(SRC)/latin/amirilatin-italic.sfdir $(SRC)/$(NAME).fea $(FEAT) $(BUILD)
	@echo "   FF	$@"
	@$(PP) -DITALIC $(SRC)/$(NAME).fea -o $(SRC)/$(NAME)-slanted.fea.pp
	@$(FF) --input $< --output $@ --features=$(SRC)/$(NAME)-slanted.fea.pp --version $(VERSION) --slant=10

$(NAME)-bold.ttf: $(SRC)/$(NAME)-bold.sfdir $(SRC)/latin/amirilatin-bold.sfdir $(SRC)/$(NAME).fea $(FEAT) $(BUILD)
	@echo "   FF	$@"
	@$(PP) $(SRC)/$(NAME).fea -o $(SRC)/$(NAME)-bold.fea.pp
	@$(FF) --input $< --output $@ --features=$(SRC)/$(NAME)-bold.fea.pp --version $(VERSION)

$(NAME)-boldslanted.ttf: $(SRC)/$(NAME)-bold.sfdir $(SRC)/latin/amirilatin-bolditalic.sfdir $(SRC)/$(NAME).fea $(FEAT) $(BUILD)
	@echo "   FF	$@"
	@$(PP) -DITALIC $(SRC)/$(NAME).fea -o $(SRC)/$(NAME)-boldslanted.fea.pp
	@$(FF) --input $< --output $@ --features=$(SRC)/$(NAME)-boldslanted.fea.pp --version $(VERSION) --slant=10

$(WEB)/%.woff $(WEB)/%.woff2: %.ttf $(MAKEWEB)
	@echo "   WEB	$*"
	@mkdir -p $(WEB)
	@$(PY) $(MAKEWEB) $< $(WEB)

$(WEB)/%.css: $(WOFF) $(MAKECSS)
	@echo "   GEN	$@"
	@mkdir -p $(WEB)
	@$(PY) $(MAKECSS) --css=$@ --fonts="$(WOFF)"

$(DOC)/$(NAME)-quran-table.pdf: $(NAME)-quran.ttf
	@echo "   GEN	$@"
	@mkdir -p $(DOC)
	@fntsample --font-file $< --output-file $@ --write-outline --use-pango

$(DOC)/$(NAME)-table.pdf: $(NAME)-regular.ttf
	@echo "   GEN	$@"
	@mkdir -p $(DOC)
	@fntsample --font-file $< --output-file $@ --write-outline --use-pango

$(DOC)/documentation-arabic.pdf: $(DOC)/documentation-arabic.tex $(DTTF)
	@echo "   GEN	$@"
	@latexmk --norc --xelatex --quiet --output-directory=${DOC} $<

check: $(TEST) $(DTTF)
	@echo "running tests"
	@$(foreach font,$(DTTF),echo "   OTS	$(font)" && ots-sanitize --quiet $(font) &&) true
	@$(PY) $(RUNTEST) $(TEST)

clean:
	rm -rfv $(DTTF) $(WOFF) $(WOF2) $(CSSS) $(PDFS) $(SRC)/$(NAME).fea.pp
	rm -rfv $(DOC)/documentation-arabic.{aux,log,toc}

distclean:
	@rm -rf $(DIST) $(DIST).zip $(WDIST) $(WDIST).zip

dist: all check pack doc
	@echo "   Making dist tarball"
	@mkdir -p $(DIST)
	@mkdir -p $(WDIST)
	@cp OFL.txt $(DIST)
	@cp OFL.txt $(WDIST)
	@cp $(DTTF) $(DIST)
	@cp README.md $(DIST)/README
	@cp README-Arabic.md $(DIST)/README-Arabic
	@cp NEWS.md $(DIST)/NEWS
	@cp NEWS-Arabic.md $(DIST)/NEWS-Arabic
	@cp $(WOFF) $(WDIST)
	@cp $(WOF2) $(WDIST)
	@cp $(CSSS) $(WDIST)
	@cp $(WEB)/README $(WDIST)
	@cp $(PDFS) $(DIST)
	@zip -r $(DIST).zip $(DIST)
	@zip -r $(WDIST).zip $(WDIST)
