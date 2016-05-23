BOOK = problems
CLS_FILES = "problems.cls","../shaddap.sty","../lmmath.sty"
# ... a list of files that's assumed to exist in the parent dir, which we
#     copy into the working dir when building the book; "CLS_" is really a misnomer
GET_CLS = perl -e 'foreach $$f($(CLS_FILES)) {$$cmd="cp ../$$f ."; system $$cmd}'
RM_CLS = rm -f problems.cls shaddap.sty lmmath.sty
SCRIPTS = ..
TEX_INTERPRETER = pdflatex
DO_PDFLATEX_RAW = $(TEX_INTERPRETER) -shell-escape -interaction=nonstopmode $(BOOK) >err

default: $(SCRIPTS)/photocredits.json
	@make preflight
	@cp ../preamble.tex $(BOOK).m4
	$(SCRIPTS)/generate_problems.rb >>$(BOOK).m4
	m4 -P ../problems.m4 book.m4 $(BOOK).m4 >$(BOOK).tex
	@$(GET_CLS)
	@echo "" >errs
	@echo "Running pdflatex..."
	@$(DO_PDFLATEX_RAW)
	@makeindex $(BOOK) >/dev/null 2>/dev/null
	@echo "Running pdflatex again..."
	@$(DO_PDFLATEX_RAW)
	@makeindex $(BOOK) >/dev/null 2>/dev/null
	@$(RM_CLS)

post:
	cp problems.pdf ~/Lightandmatter/problems

clean:
	rm -f $(BOOK).aux $(BOOK).log err *~
	$(RM_CLS)

preflight:
	@chmod +x $(SCRIPTS)/generate_problems.rb $(SCRIPTS)/photocredits.rb

$(SCRIPTS)/photocredits.json: $(SCRIPTS)/photocredits.rb
	@make preflight
	$(SCRIPTS)/photocredits.rb >$(SCRIPTS)/photocredits.json
