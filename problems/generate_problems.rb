#!/usr/bin/ruby

# generate_problems.rb /path/to/spotter/dir instr data_dir instr_dir 
#   first arg is where spotter dir is
#   instr = 0 or 1, indicates whether this is the instructor's version
#   data_dir is where fig_widths and fig_widths_by_hand files are
#   instr_dir is directory where the solutions are
# prints m4/latex output to stdout
# as a side-effect, writes a spotter answer file to spotter.m4

require 'json'

def fatal_error(message)
  $stderr.print "generate_problems.rb: #{$verb} fatal error: #{message}\n"
  exit(-1)
end

def warning(message)
  $stderr.print "generate_problems.rb: #{$verb} warning: #{message}\n"
end

def informational_message(message)
  $stderr.print "generate_problems.rb: #{$verb} informational message: #{message}\n"
end

# returns contents or nil on error; for more detailed error reporting, see slurp_file_with_detailed_error_reporting()
def slurp_file(file)
  x = slurp_file_with_detailed_error_reporting(file)
  return x[0]
end

def slurp_or_die(file)
  x = slurp_file_with_detailed_error_reporting(file)
  x = x[0]
  if x.nil? then fatal_error("file #{file} not found") end
  return x
end

# returns [contents,nil] normally [nil,error message] otherwise
def slurp_file_with_detailed_error_reporting(file)
  begin
    File.open(file,'r') { |f|
      t = f.gets(nil) # nil means read whole file
      if t.nil? then t='' end # gets returns nil at EOF, which means it returns nil if file is empty
      return [t,nil]
    }
  rescue
    return [nil,"Error opening file #{file} for input, cwd=#{Dir.pwd}: #{$!}."]
  end
end

def get_json_data_from_file_or_die(file)
  r = slurp_file_with_detailed_error_reporting(file)
  if !(r[1].nil?) then fatal_error(r[1]) end
  return parse_json_or_die(r[0])
end

def parse_json_or_die(json)
  begin
    return JSON.parse(JSMin.minify(json)) # use minifier to get rid of comments
  rescue JSON::ParserError
    fatal_error("syntax error in JSON string '#{json}'")
  end
end

def get_problems_data(problems_csv) # used in order to determine which problems have publicly available solutions
  # return value is a hash like {"mg-to-kg"=>true,...}
  # lm,0,1,calculator,0
  # book,chapter,number,label,solution
  result = {}
  csv = slurp_file(problems_csv)
  csv.split(/\n/).each { |line|
    if line=~/\A([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)\Z/ then
      book,chapter,number,label,solution = [$1,$2.to_i,$3,$4,$5.to_i]
      debug = false # (label=="mg-to-kg")
      result[label] = (solution==1)
      if debug then $stderr.print "result[label]=#{result[label]}\n" end
    else
      fatal_error("can't parse this line in #{infile}: #{line}")
    end
  }
  return result
end

#--------------------------------------------------------------------------

# usage: JSMin.minify(js)
# https://github.com/rgrove/jsmin
#--
# jsmin.rb - Ruby implementation of Douglas Crockford's JSMin.
#
# This is a port of jsmin.c, and is distributed under the same terms, which are
# as follows:
#
# Copyright (c) 2002 Douglas Crockford  (www.crockford.com)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# The Software shall be used for Good, not Evil.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#++

require 'strscan'

# = JSMin
#
# Ruby implementation of Douglas Crockford's JavaScript minifier, JSMin.
#
# *Author*::    Ryan Grove (mailto:ryan@wonko.com)
# *Version*::   1.0.1 (2008-11-10)
# *Copyright*:: Copyright (c) 2008 Ryan Grove. All rights reserved.
# *Website*::   http://github.com/rgrove/jsmin
#
# == Example
#
#   require 'rubygems'
#   require 'jsmin'
#
#   File.open('example.js', 'r') {|file| puts JSMin.minify(file) }
#
module JSMin
  CHR_APOS       = "'".freeze
  CHR_ASTERISK   = '*'.freeze
  CHR_BACKSLASH  = '\\'.freeze
  CHR_CR         = "\r".freeze
  CHR_FRONTSLASH = '/'.freeze
  CHR_LF         = "\n".freeze
  CHR_QUOTE      = '"'.freeze
  CHR_SPACE      = ' '.freeze

  ORD_LF    = ?\n
  ORD_SPACE = ?\ 
  ORD_TILDE = ?~

  class ParseError < RuntimeError
    attr_accessor :source, :line
    def initialize(err, source, line)
      @source = source,
      @line = line
      super "JSMin Parse Error: #{err} at line #{line} of #{source}"
    end
  end

  class << self
    def raise(err)
      super ParseError.new(err, @source, @line)
    end

    # Reads JavaScript from _input_ (which can be a String or an IO object) and
    # returns a String containing minified JS.
    def minify(input)
      @js = StringScanner.new(input.is_a?(IO) ? input.read : input.to_s)
      @source = input.is_a?(IO) ? input.inspect : input.to_s[0..100]
      @line = 1

      @a         = "\n"
      @b         = nil
      @lookahead = nil
      @output    = ''

      action_get

      while !@a.nil? do
        case @a
        when CHR_SPACE
          if alphanum?(@b)
            action_output
          else
            action_copy
          end

        when CHR_LF
          if @b == CHR_SPACE
            action_get
          elsif @b =~ /[{\[\(+-]/
            action_output
          else
            if alphanum?(@b)
              action_output
            else
              action_copy
            end
          end

        else
          if @b == CHR_SPACE
            if alphanum?(@a)
              action_output
            else
              action_get
            end
          elsif @b == CHR_LF
            if @a =~ /[}\]\)\\"+-]/
              action_output
            else
              if alphanum?(@a)
                action_output
              else
                action_get
              end
            end
          else
            action_output
          end
        end
      end

      @output
    end

    private

    # Corresponds to action(1) in jsmin.c.
    def action_output
      @output << @a
      action_copy
    end

    # Corresponds to action(2) in jsmin.c.
    def action_copy
      @a = @b

      if @a == CHR_APOS || @a == CHR_QUOTE
        loop do
          @output << @a
          @a = get

          break if @a == @b

          if @a[0] <= ORD_LF
            raise "unterminated string literal: #{@a.inspect}"
          end

          if @a == CHR_BACKSLASH
            @output << @a
            @a = get

            if @a[0] <= ORD_LF
              raise "unterminated string literal: #{@a.inspect}"
            end
          end
        end
      end

      action_get
    end

    # Corresponds to action(3) in jsmin.c.
    def action_get
      @b = nextchar

      if @b == CHR_FRONTSLASH && (@a == CHR_LF || @a =~ /[\(,=:\[!&|?{};]/)
        @output << @a
        @output << @b

        loop do
          @a = get

           # Inside a regex [...] set, which MAY contain a '/' itself.
           # Example:
           #   mootools Form.Validator near line 460:
           #     return Form.Validator.getValidator('IsEmpty').test(element) || (/^(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]\.?){0,63}[a-z0-9!#$%&'*+/=?^_`{|}~-]@(?:(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\])$/i).test(element.get('value'));
          if @a == '['
            loop do
              @output << @a
              @a = get
              case @a
                when ']' then break
                when CHR_BACKSLASH then
                  @output << @a
                  @a = get
                when @a[0] <= ORD_LF
                  raise "JSMin parse error: unterminated regular expression " +
                      "literal: #{@a}"
              end
            end
          elsif @a == CHR_FRONTSLASH
            break
          elsif @a == CHR_BACKSLASH
            @output << @a
            @a = get
          elsif @a[0] <= ORD_LF
            raise "unterminated regular expression : #{@a.inspect}"
          end

          @output << @a
        end

        @b = nextchar
      end
    end

    # Returns true if +c+ is a letter, digit, underscore, dollar sign,
    # backslash, or non-ASCII character.
    def alphanum?(c)
      c.is_a?(String) && !c.empty? && (c[0] > ORD_TILDE || c =~ /[0-9a-z_$\\]/i)
    end

    # Returns the next character from the input. If the character is a control
    # character, it will be translated to a space or linefeed.
    def get
      if @lookahead
        c = @lookahead
        @lookahead = nil
      else
        c = @js.getch
        if c == CHR_LF || c == CHR_CR
          @line += 1
          return CHR_LF
        end
        return ' ' unless c.nil? || c[0] >= ORD_SPACE
      end
      c
    end

    # Gets the next character, excluding comments.
    def nextchar
      c = get
      return c unless c == CHR_FRONTSLASH

      case peek
      when CHR_FRONTSLASH
        loop do
          c = get
          return c if c[0] <= ORD_LF
        end

      when CHR_ASTERISK
        get
        loop do
          case get
          when CHR_ASTERISK
            if peek == CHR_FRONTSLASH
              get
              return ' '
            end

          when nil
            raise 'unterminated comment'
          end
        end

      else
        return c
      end
    end

    # Gets the next character without getting it.
    def peek
      @lookahead = get
    end
  end
end

#-------------------------------------------------------------

def filter_out_eruby(t)
  result = ''
  inside = false # even if there is a ruby expression at the very beginning of the string, split() gives us a null string as our first string
  t.split(/(?:\<\%|\%\>)/).each { |x|
    if !inside then result = result+x end
    inside = !inside
  }
  return result
end

def clean_up_hw(t)
  result = t.gsub(/^%%%%%(.*)\n/) {''}
  result.gsub!(/%\s*meta\s*(.*)/) {''}
  result.gsub!(/\A\s+/) {''}
  result.gsub!(/\n*\Z/) {''}
  return result
end

#-------------------------------------------------------------
def find_problem_file(prob,location)
  # look first in current directory:
  file = Dir.getwd+"/"+prob+".tex"
  if File.exist?(file) then return [file,nil] end
  # if not, then look in shared directory:
  file = $original_dir+"/../../"+location+"/hw/"+prob+".tex"
  if File.exist?(file) then return [file,nil] end
  if prob=~/\.tex$/ then return [nil,"file #{file} not found, probably because you shouldn't have included .tex in this.config"] end
  return [nil,"file #{prob}.tex not found in #{Dir.getwd} or #{$original_dir+"/../../"+location+"/hw"}"]
end

def extract_meta(t)
  h = {}
  t.scan(/%\s*meta\s*(.*)/) { |x|
    json = x[0]
    h = h.merge(parse_json_or_die(json))
  }
  return h
end

def fig_width(fig) # fig is the bare name of the figure, e.g., "weasel", not "weasel.jpg"
  # return value is "narrow", "wide", or "fullpage"
  result = 'narrow'
  if $fig_widths.key?(fig) then result = $fig_widths[fig] end
  return result
end

def find_fig_file_in_dir(dir,f) # returns [boolean,"foo","/.../.../foo.png",width]
  # return value width is "narrow", "wide", or "fullpage"
  ["png","jpg","pdf"].each { |type|
    g = "#{dir}/#{f}.#{type}"
    if File.exist?(g) then return [true,f,g,fig_width(f)] end
  }
  return [false,nil,nil,nil]
end

def find_fig_for_problem(prob,files) # returns [boolean,"foo","/.../.../foo.png",width]
  # files = a directory, can be relative, with /figs implied on the end, or absolute
  # return value width is "narrow", "wide", or "fullpage"
  ['','hw-','eg-'].each { |prefix|
    f = "#{prefix}#{prob}"
    places = []
    if !(files.nil?) then 
      # detect whether it's relative or absolute
      if Dir.exist?(files) then
        places.push(files)
      else
        places.push($original_dir+"/../../"+files+"/figs")
      end
    end
    places.push($original_dir+"/../../me/end/figs") # me/end/figs has some figures for solutions
    places.each { |dir| 
      r = find_fig_file_in_dir(dir,f)
      if r[0] then return r end
    }
  }
  return [false,nil,nil]
end

def find_anonymous_inline_figs(tex)
  return tex.gsub(/\\anonymousinlinefig{([^}]*)}/) {
    f = ''
    find = find_fig_for_problem($1,nil)
    if find[0] then f=find[2] end
    "\\anonymousinlinefig{#{f}}"
  }
end

def find_figs_for_solution(prob,orig,instr_dir=nil)
  #debug = (prob=~/truck/)
  debug = false
  $stderr.print "in find_figs_for_solution, prob=#{prob}" if debug
  tex = orig.clone # qwe
  figs_dir = nil
  if !(instr_dir.nil?) then found,solution,figs_dir = find_instructor_solution(prob,instr_dir) end
  macros = ["anonymousinlinefig","fig"]
  macros.each { |m|
    tex.gsub!(/\\#{m}{([^}]*)}/) {
      fig_name = $1
      f = ''
      find = find_fig_for_problem(fig_name,figs_dir)
      if find[0] then 
        f=find[2]
      else
        fatal_error("fig not found by find_figs_for_solution, prob=#{prob}, fig_name=#{fig_name}, figs_dir=#{figs_dir}")
      end
      $stderr.print "in find_figs_for_solution, prob=#{prob}, f=#{f}" if debug
      "\\anonymousinlinefig{#{f}}"
    }
  }
  return tex
end

def generate_chapter_header(title,path_label)
  boilerplate = slurp_file("#{$original_dir}/../chapter_header_boilerplate.tex")
  if boilerplate.nil? then boilerplate='' end
  print <<-HEADER

      %%%%%%%%%%% ch: #{title} %%%%%%%%%%%
      \\chapter{#{title}}\\label{ch:#{path_label}}
      #{boilerplate}
    HEADER
end

def get_meta_data_with_default(meta,key,default)
  result = default
  if meta.key?(key) then result=meta[key] end
  return result
end

def die_if_bogus_xml(xml_file,prob)
  xml = slurp_or_die(xml_file)
  # look for, e.g., <problem id="avg-velocity-bike-ride">
  if !(xml=~/(<problem\s+id="([^"]+)">)/) then
    warning("file xml_file does not appear to have a <problem id=\"...\">")
    return
  end
  id_inside_file = $2
  if prob!=id_inside_file then
    fatal_error("in file #{xml_file}, #{$1} says id is #{$2}, should be #{prob}")
  end
end

def generate_photo_credit(fig_file)
  if $credits.key?(fig_file) then
    description,credit = $credits[fig_file]
    $credits_tex = $credits_tex + "\\cred{#{fig_file}}{#{description}}{#{credit}}"
  end
end

def generate_prob_tex(prob,group,k,solutions,files,counters)
  # returns latex for the problem
  # side-effects (when appropriate):
  #   adds to $credits_tex
  #   adds to spotter output in $spotter1 and $spotter2
  file,err = find_problem_file(prob,files)
  if file.nil? then warning(err); return '' end
  debug = false # (prob=~/pluto/)
  label = group+k.to_s
  tex = slurp_file(file)
  meta = extract_meta(tex)
  if $save_meta.key?(prob) then fatal_error("problem #{prob} occurs twice; second time is in prob=#{prob} group=#{group} files=#{files}") end
  $save_meta[prob] = meta
  tex = clean_up_hw(filter_out_eruby(tex))
  stars = get_meta_data_with_default(meta,"stars",0)
  ch = counters[1]
  result = <<-RESULT
    \n\n%%%%%%%%%%%%%%%% #{prob} %%%%%%%%%%%%%%%%
    \\begin{hw}{#{prob}}{#{stars}}{0}{#{ch}-#{label}}
    #{tex}\n
    RESULT
  if solutions[prob] || meta["solution"]==1 then result =result+"\\hwsoln\n" end
  result = result + "\\end{hw}\n"
  has_fig,fig_file,fig_path,width = find_fig_for_problem(prob,files)
  if has_fig then
    result = result+process_fig(fig_file,width,"Problem \\ref{hw:#{prob}}.",true)
  end
  if !($spotter_dir.nil?) then
    if debug then $stderr.print "looking for spotter stuff for #{prob}" end
    bogus_xml_filename = "#{$spotter_dir}/xml/#{prob}.tex" # misnaming it .tex, which I always do by mistake
    if File.exist?(bogus_xml_filename) then fatal_error("File #{bogus_xml_filename} exists, should end in .xml, not .tex") end
    xml_fragment = "#{$spotter_dir}/xml/#{prob}.xml"
    check_exists = File.exist?(xml_fragment)
    claims_check_exists = (tex =~ /\\answercheck/)
    if check_exists then
      $spotter1 = $spotter1 + "<num id=\"#{prob}\" label=\"#{label}\"/>\n"
      $spotter2 = $spotter2 + "m4_include(xml/#{prob}.xml)\n"
      die_if_bogus_xml(xml_fragment,prob)
    end
    if check_exists && !claims_check_exists then
      warning("problem #{prob} has an answer check in #{xml_fragment},\n  but file #{file} doesn't have \\answercheck")
    end
    if !check_exists && claims_check_exists then
      warning("for problem #{ch}-#{label}, #{prob},\n  file #{File.expand_path(file)} has \\answercheck,\n  but no file #{xml_fragment} exists")
    end
  end
  return result
end

def find_instructor_solution(prob,instr_dir)
  # returns [found,file,figs_dir]
  found = false
  found_file = nil
  topics = ["intro","mechanics","waves","em-dc","em-fields","em-general","optics","relativity","quantum"]
  topics.each { |subdir|
    found_file = "#{instr_dir}/#{subdir}/#{prob}.tex"
    if File.exist?(found_file) then return[true,found_file,"#{instr_dir}/#{subdir}/figs"] end
  }
  return [false,nil,nil]
end

def generate_solution_tex(answers_dir,prob,group,k,path,counters,instr=false,instr_dir=nil) # qwe
  debug = false
  #debug = (prob=~/cross/)
  $stderr.print "entering generate_solution_tex, prob=#{prob}\n" if debug
  ch = counters[1]
  found = false
  instr_only = nil
  file = answers_dir+"/"+prob+".tex" # student solution
  figs_dir = nil
  if File.exist?(file) then
    found=true
    instr_only = false
  else
    found,file,figs_dir = find_instructor_solution(prob,instr_dir)
    instr_only = true
  end
  $stderr.print "file=#{file}, #{file.nil?}, found=#{found}\n" if debug
  if !instr && !found then warning("no solution found for problem #{ch}-#{group}#{k}, #{prob}, which is supposed to have a solution in the back of the student's version; solutions should typically go in physics/share/answers"); return '' end
  if instr && !found then warning("no solution found for problem #{ch}-#{group}#{k}, #{prob}"); return '' end
  label = group+k.to_s
  if instr_only then
    $stderr.print "calling find_figs_for_solution, prob=#{prob}, file=#{file}\n" if debug
    soln = find_figs_for_solution(prob,slurp_file(file),instr_dir)
  else
    soln = find_figs_for_solution(prob,slurp_file(file))
  end
  # soln.gsub!(/\\(begin|end){soln}/) {''} # these are no longer present in individual files
  result = ''
  result = result+"\n\n%%%%%%%%%%%%%%%% solution to #{prob} %%%%%%%%%%%%%%%%\n"
  result = result+"\\solnhdr{\\ref{ch:#{path[0]}}-#{label}}\\label{soln:#{ch}-#{label}}\n"
  result = result+soln+"\n"
  $stderr.print "done with generate_solution_tex, result=#{result}\n" if debug
  return result
end

def process_fig(fig_file,width,caption,allow_time_travel)
  # returns latex code for the figure
  # has the side-effect of generating a photo credit
  # width can be narrow (52 mm), medium (1 column), wide, or fullpage
  macro = 'fignarrow'
  add_before,add_after = '',''
  if width=='medium' then
    macro='fig'
  else
    if width!='narrow' then
      macro='figwide'
      if allow_time_travel then
        add_before="\n\\begin{timetravel}\n";add_after="\n\\end{timetravel}\n" 
      end
    end
  end
  generate_photo_credit(fig_file)
  return "#{add_before}\\#{macro}{#{fig_file}}{}{#{caption}}#{add_after}\n"
end

def process_text(tex)
  # handles figures, which look like this:
  #       % fig {"name":"munchausen","caption":"Escaping from a swamp."}
  # has the side effect of generating photo credits
  tex.gsub!(/^%\s*fig\s*(.*)$/) { |line|
    fig_data = parse_json_or_die($1)
    fig = fig_data["name"]
    caption = fig_data["caption"]
    if fig_data.key?("width") then width=fig_data["width"] else width = fig_width(fig) end
    allow_time_travel = true
    #if fig_data.key?("timetravel") then allow_time_travel=(fig_data["width"]!=0) end
    if fig_data.key?("timetravel") then allow_time_travel=false end
    process_fig(fig,width,caption,allow_time_travel)
  }
  return tex
end

def generate_content(what,depth,json,files,group,path,solutions,answers_dir,counters)
  # depth 0=book, 1=chapter, 2=section, 3=problem group
  debug = false
  path_label = path.join('-')
  print "\\renewcommand{\\sharedfigs}{#{files}/figs}"
  if what=="text" then
    title = json["title"]
    if depth==1 then print generate_chapter_header(title,path_label) end
    if depth==2 then print "\n%%%%%%%%%%% sec: #{title} %%%%%%%%%%%\n\\section{#{title}}\\label{sec:#{path_label}}\n" end
    if File.exist?("text.tex") then print process_text(slurp_file("text.tex")) end
  end
  if depth==3 then
    if json.key?("order") && !(json["order"].nil?) then
      order = json["order"]
      k = 0
      order.each { |prob|
        if prob=='' then fatal_error("problem is a null string, problem group=#{group}, counters=#{counters.join(',')}") end
        k = k+1
        if what=="problems" then
          print generate_prob_tex(prob,group,k,solutions,files,counters)
                  # ... has side effects of adding to $credits_tex, $spotter1, and $spotter2, if appropriate
        end
        if what=="answers" then
          if $instructor then
            print generate_solution_tex(answers_dir,prob,group,k,path,counters,true,$instr_dir)
          else
            if $save_meta[prob].nil? then
              $stderr.print "qwe prob=#{prob}\n"
            end
            if solutions[prob] || $save_meta[prob]["solution"]==1 then
              print generate_solution_tex(answers_dir,prob,group,k,path,counters)
            end
          end
        end
      }
    end
  end
end

def do_stuff(what,depth,files,group,path,solutions,answers_dir,counters) # recursive
  # depth 0=book, 1=chapter, 2=section, 3=problem group
  debug = false
  counters[depth+1] = 0 # e.g., if depth=0 then set the chapter number to 0
  indent = "  "*depth
  $stderr.print "#{indent}what=#{what}, depth=#{depth}\n" if debug
  json = get_json_data_from_file_or_die("this.config")
  if json.key?("files") then files=json["files"] end
  if what=="answers" && depth==0 then
    print "\\chapter*{Answers}\n"
  end
  generate_content(what,depth,json,files,group,path,solutions,answers_dir,counters)
  if json.key?("order") then
    order = json["order"]
    if depth <= 2 then
      subdirs = []
      if order.kind_of?(Array) then
        subdirs = order
      end
      if order.kind_of?(Hash) then
        groups = order.keys.sort # bug: sort won't work if keys are like "aa", etc.
        groups.each { |g|
          subdirs.push(order[g])
        }
      end
      subdirs.each { |dir|
        save_dir = Dir.getwd
        Dir.chdir(dir)
        g = group
        if depth==2 then g=order.key(dir) end
        path.push(dir)
        counters[depth+1] = counters[depth+1]+1
        do_stuff(what,depth+1,files,g,path,solutions,answers_dir,counters) # recursion
        path.pop
        Dir.chdir(save_dir)
      }
    end
  end
  if what=="text" && depth==1 then
    print "\\begin{hwsection}\n"
    ch = counters[1]
    $spotter1 = $spotter1+"\n\n<!-- ch #{ch}, #{json["title"]} -->\n\n"
    $spotter2 = $spotter2+"\n\n<toc type=\"chapter\" num=\"#{ch}\" title=\"#{json["title"]}\">\n\n"
    do_stuff("problems",depth,files,group,path,solutions,answers_dir,counters)
    print "\\end{hwsection}\n"
    $spotter2 = $spotter2+"\n\n</toc>\n\n"
  end
end

def main()
  $spotter_dir = ARGV[0]
  if !($spotter_dir.nil?) && !(Dir.exist?($spotter_dir)) then 
    warning("spotter directory #{$spotter_dir} doesn't exist") 
    $spotter_dir = nil
  end
  $instructor = ARGV[1]=='1' # is this the instructor's version?
  $data_dir = ARGV[2] # contains fig_widths file
  $instr_dir = ARGV[3]
  if $instructor && !(Dir.exist?($instr_dir)) then
    warning("directory #{$instr_dir} doesn't exist")
    $instructor = false
  end
  $fig_widths = get_json_data_from_file_or_die("#{$data_dir}/fig_widths")
  $fig_widths = $fig_widths.merge(get_json_data_from_file_or_die("#{$data_dir}/fig_widths_by_hand"))
  $original_dir = Dir.getwd
  $credits_tex = "\\input{../credits_header.tex}"
  $credits = get_json_data_from_file_or_die($original_dir+"/../photocredits.json")
  $save_meta = {}
  $spotter1 = '' # header info for spotter .xml file
  $spotter2 = '' # body of spotter .xml file
  book_config = get_json_data_from_file_or_die("#{$original_dir}/this.config")
  title = book_config["title"]
  if $instructor then title = title+", Instructor's Edition" end
  solutions = get_problems_data($original_dir+"/../../data/problems.csv")
  answers_dir = $original_dir+"/../../share/answers"
  $spotter1 = slurp_or_die($original_dir+"/../spotter_header") 
  $spotter1 = $spotter1 + "<spotter title=\"#{title}\">\n<log_file ext=\"log\"/>\n"
  $spotter2 = ''
  print <<-'TOP'
    \documentclass{problems}
    \begin{document}
    TOP
  print slurp_or_die($original_dir+"/front_matter.tex").gsub!(/__title__/) {title}
  print "\\timetravelenable"
  stuff_to_do = ["text","hints","answers"] # there is also "problems", which is triggered after the text for a chapter
  stuff_to_do.each { |what| 
    do_stuff(what,0,'','',[],solutions,answers_dir,[])
  }
  print $credits_tex
  print <<-'BOTTOM'
    \input{../postamble.tex}
    \end{document}
    BOTTOM
  if !($spotter_dir.nil?) then
    File.open('spotter.m4','w') { |f|
      f.print $spotter1+"\n\n<toc_level level=\"0\" type=\"chapter\"/>"+$spotter2+"\n</spotter>\n"
    }
  end
end

main()
