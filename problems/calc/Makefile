BOOK = problems
INSTR = instr
CLS_FILES = "problems.cls","../shaddap.sty","../lmmath.sty"
# ... a list of files that's assumed to exist in the parent dir, which we
#     copy into the working dir when building the book; "CLS_" is really a misnomer
GET_CLS = perl -e 'foreach $$f($(CLS_FILES)) {$$cmd="cp ../$$f ."; system $$cmd}'
RM_CLS = rm -f problems.cls shaddap.sty lmmath.sty
SCRIPTS = ..
TEX_INTERPRETER = pdflatex
DO_PDFLATEX_RAW = $(TEX_INTERPRETER) -shell-escape -interaction=nonstopmode $(BOOK) >err
SPOTTER_DIR = /home/bcrowell/Documents/programming/spotter/answers

-include ../password.make # - means don't throw an error if it's not present

default: $(SCRIPTS)/photocredits.json
	@make preflight
	@cp ../preamble.tex $(BOOK).m4
	$(SCRIPTS)/generate_problems.rb $(SPOTTER_DIR) 0 >>$(BOOK).m4
	m4 -P ../problems.m4 book.m4 $(BOOK).m4 >$(BOOK).tex
	@$(GET_CLS)
	@echo "Running pdflatex..."
	@$(DO_PDFLATEX_RAW)
	@makeindex $(BOOK) >/dev/null 2>/dev/null
	@echo "Running pdflatex again..."
	@$(DO_PDFLATEX_RAW)
	@makeindex $(BOOK) >/dev/null 2>/dev/null
	@$(RM_CLS)
	@cp spotter.m4 $(SPOTTER_DIR)/$(BOOK).m4
	@cd $(SPOTTER_DIR) ; make ; cd -

instr:
	cp ../preamble.tex temp.m4
	$(SCRIPTS)/generate_problems.rb $(SPOTTER_DIR) 1 $(SOLUTIONS_DIR) >>temp.m4
	m4 -P ../problems.m4 book.m4 temp.m4 >temp.tex
	$(GET_CLS)
	pdflatex temp >err
	makeindex temp >/dev/null 2>/dev/null
	pdflatex temp >err
	makeindex temp >/dev/null 2>/dev/null
	$(RM_CLS)
	pdftk temp.pdf output $(INSTR).pdf encrypt_128bit user_pw $(PASSWORD_UNQUOTED) # should do this with qpdf instead

all:
	make
	make instr
	make post

post:
	cp problems.pdf ~/Lightandmatter/problems
	-cp $(INSTR).pdf ~/Lightandmatter/problems

clean:
	rm -f $(BOOK).aux $(BOOK).log $(INSTR).pdf err *~ temp.*
	$(RM_CLS)

preflight:
	@chmod +x $(SCRIPTS)/generate_problems.rb $(SCRIPTS)/photocredits.rb

$(SCRIPTS)/photocredits.json: $(SCRIPTS)/photocredits.rb
	@make preflight
	$(SCRIPTS)/photocredits.rb >$(SCRIPTS)/photocredits.json
