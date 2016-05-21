BOOK = problems
CLS_FILES = "problems.cls","../shaddap.sty","../lmmath.sty"
# ... a list of files that's assumed to exist in the parent dir, which we
#     copy into the working dir when building the book; "CLS_" is really a misnomer
GET_CLS = perl -e 'foreach $$f($(CLS_FILES)) {$$cmd="cp ../$$f ."; system $$cmd}'
SCRIPTS = ..

default:
	$(SCRIPTS)/generate_problems.rb >$(BOOK).tex
	@$(GET_CLS)
	@echo "" >errs
	@pdflatex $(BOOK) >>errs
	@pdflatex $(BOOK) >>errs

clean:
	rm -f $(BOOK).aux $(BOOK).log errs *~
