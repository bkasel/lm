BOOK = problems
INSTR = instr
CLS_FILES = "problems.cls","../shaddap.sty","../lmmath.sty","timetravel.sty"
# ... a list of files that's assumed to exist in the parent dir, which we
#     copy into the working dir when building the book; "CLS_" is really a misnomer
GET_CLS = perl -e 'foreach $$f($(CLS_FILES)) {$$cmd="cp ../$$f ."; system $$cmd}'
RM_CLS = rm -f problems.cls shaddap.sty lmmath.sty timetravel.sty
SCRIPTS = ..
TEX_INTERPRETER = pdflatex
DO_PDFLATEX_RAW = $(TEX_INTERPRETER) -shell-escape -interaction=nonstopmode $(BOOK) >err
SPOTTER_DIR = /home/bcrowell/Documents/programming/spotter/answers
DATA_DIR = ../../data

.SILENT: # suppress messages such as "entering directory"

-include ../password.make # - means don't throw an error if it's not present

all: $(SCRIPTS)/photocredits.json
	make student
	make instr
	@make post
	@echo "Both versions of the book are made and posted. You can do a make clean if you like."

student: $(SCRIPTS)/photocredits.json
	@make preflight
	@make init-timetravel
	@cp ../preamble.tex $(BOOK).m4
	$(SCRIPTS)/generate_problems.rb $(SPOTTER_DIR) 0 $(DATA_DIR) >>$(BOOK).m4
	m4 -P ../problems.m4 book.m4 $(BOOK).m4 >$(BOOK).tex
	@$(GET_CLS)
	@echo "Running pdflatex..."
	@$(SCRIPTS)/timetravel.rb $(BOOK).tex
	@$(DO_PDFLATEX_RAW)
	@echo "Running pdflatex three more times..."
	@$(SCRIPTS)/timetravel.rb $(BOOK).tex
	@$(DO_PDFLATEX_RAW)
	@makeindex $(BOOK) >/dev/null 2>/dev/null
	@$(SCRIPTS)/timetravel.rb $(BOOK).tex
	@$(DO_PDFLATEX_RAW)
	@makeindex $(BOOK) >/dev/null 2>/dev/null
	# one more time...? --
	@$(DO_PDFLATEX_RAW)
	@makeindex $(BOOK) >/dev/null 2>/dev/null
        #
	@$(RM_CLS)
	@echo "Making new version of $(SPOTTER_DIR)/$(BOOK).xml"
	@cp spotter.m4 $(SPOTTER_DIR)/$(BOOK).m4
	@cd $(SPOTTER_DIR) ; make ; cd -

instr: $(SCRIPTS)/photocredits.json
	@make preflight
	@make init-timetravel
	cp ../preamble.tex temp.m4
	$(SCRIPTS)/generate_problems.rb $(SPOTTER_DIR) 1 $(DATA_DIR) $(SOLUTIONS_DIR) >>temp.m4
	m4 -P ../problems.m4 book.m4 temp.m4 >temp.tex
	$(GET_CLS)
	@$(SCRIPTS)/timetravel.rb temp.tex
	pdflatex temp >err
	makeindex temp >/dev/null 2>/dev/null
	@$(SCRIPTS)/timetravel.rb temp.tex
	pdflatex temp >err
	makeindex temp >/dev/null 2>/dev/null
	@$(SCRIPTS)/timetravel.rb temp.tex
	pdflatex temp >err
	makeindex temp >/dev/null 2>/dev/null
	$(RM_CLS)
	pdftk temp.pdf output $(INSTR).pdf encrypt_128bit user_pw $(PASSWORD_UNQUOTED) # should do this with qpdf instead
	@echo "An unencrypted copy of the instructor's version is in temp.pdf. An encrypted one is in $(INSTR).pdf."

post:
	@cp problems.pdf ~/Lightandmatter/problems
	@-cp $(INSTR).pdf ~/Lightandmatter/problems

clean:
	rm -f $(BOOK).aux $(BOOK).log $(INSTR).pdf err *~ temp.*
	$(RM_CLS)
	rm -Rf timetravel

init-timetravel:
	@rm -f *.aux *.ind
	@rm -Rf timetravel

preflight:
	# make sure we always have latest version of timetravel package:
	@-cp ~/Documents/programming/timetravel/timetravel.rb $(SCRIPTS) 
	@-cp ~/Documents/programming/timetravel/timetravel.sty $(SCRIPTS) 
	# make sure scripts are executable:
	@chmod +x $(SCRIPTS)/generate_problems.rb $(SCRIPTS)/photocredits.rb $(SCRIPTS)/timetravel.rb

$(SCRIPTS)/photocredits.json: $(SCRIPTS)/photocredits.rb
	@make preflight
	$(SCRIPTS)/photocredits.rb >$(SCRIPTS)/photocredits.json
