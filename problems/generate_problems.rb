#!/usr/bin/ruby

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
    return [nil,"Error opening file #{file} for input: #{$!}."]
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

def find_fig_for_problem(prob,files)
  dir = files+"/figs"
  ["png","jpg","pdf"].each { |type|
    ['','hw-'].each { |prefix|
      f = "#{prefix}#{prob}"
      g = $original_dir+"/../../#{dir}/#{f}.#{type}"
      if File.exist?(g) then return [true,f,g] end
    }
  }
  return [false,nil,nil]
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

def generate_content(what,depth,json,files,group,path,solutions,answers_dir)
  # depth 0=book, 1=chapter, 2=section, 3=problem group
  debug = false
  path_label = path.join('-')
  print "\\renewcommand{\\sharedfigs}{#{files}/figs}"
  if what=="text" then
    title = json["title"]
    if depth==1 then print generate_chapter_header(title,path_label) end
    if depth==2 then print "\n%%%%%%%%%%% sec: #{title} %%%%%%%%%%%\n\\section{#{title}}\\label{sec:#{path_label}}\n" end
    if File.exist?("text.tex") then print slurp_file("text.tex") end
  end
  if what=="problems" then
    if depth==3 then
      if json.key?("order") then
        order = json["order"]
        k = 1
        order.each { |prob|
          $stderr.print "        prob=#{prob} group=#{group} files=#{files}\n" if debug
          file,err = find_problem_file(prob,files)
          if file.nil? then warning(err); next end
          label = group+k.to_s
          t = slurp_file(file)
          meta = extract_meta(t)
          $save_meta[prob] = meta
          t = clean_up_hw(filter_out_eruby(t))
          # $stderr.print "meta=#{JSON.generate(meta)}\n"
          stars = 0 # default
          if meta.key?("stars") then stars=meta["stars"] end
          print "\n\n%%%%%%%%%%%%%%%% #{prob} %%%%%%%%%%%%%%%%\n"
          print "\\begin{hw}{#{prob}}{#{stars}}{0}{#{label}}\n"
          print t+"\n"
          if solutions[prob] || meta["solution"]==1 then print "\\hwsoln\n" end
          print "\\end{hw}\n"
          has_fig,fig_file,fig_path = find_fig_for_problem(prob,files)
          if has_fig then
            print "\\fignarrow{#{fig_file}}{}{Problem \\ref{hw:#{prob}}.}\n"
            if $credits.key?(fig_file) then
              description,credit = $credits[fig_file]
              $credits_tex = $credits_tex + "\\cred{#{fig_file}}{#{description}}{#{credit}}"
            end
          end
          k = k+1
        }
      end
    end
  end
  if what=="answers" then
    if depth==3 then
      if json.key?("order") then
        order = json["order"]
        k = 1
        order.each { |prob|
          if solutions[prob] || $save_meta[prob]["solution"]==1 then
            file = answers_dir+"/"+prob+".tex"
            label = group+k.to_s
            soln = slurp_file(file)
            print "\n\n%%%%%%%%%%%%%%%% solution to #{prob} %%%%%%%%%%%%%%%%\n"
            #print "solution to problem \\ref{ch:#{path[0]}}-#{label}\\label{soln:#{label}}\n"
            print "\\solnhdr{\\ref{ch:#{path[0]}}-#{label}}\\label{soln:#{label}}\n"
            print soln+"\n"
          end
          k = k+1
        }
      end
    end
  end
end

def do_stuff(what,depth,files,group,path,solutions,answers_dir) # recursive
  # depth 0=book, 1=chapter, 2=section, 3=problem group
  debug = false
  indent = "  "*depth
  $stderr.print "#{indent}what=#{what}, depth=#{depth}\n" if debug
  json = get_json_data_from_file_or_die("this.config")
  if json.key?("files") then files=json["files"] end
  if what=="answers" && depth==0 then
    print "\\chapter*{Answers}\n"
  end
  generate_content(what,depth,json,files,group,path,solutions,answers_dir)
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
        do_stuff(what,depth+1,files,g,path,solutions,answers_dir) # recursion
        path.pop
        Dir.chdir(save_dir)
      }
    end
  end
  if what=="text" && depth==1 then
    print "\\section*{Problems}\n"
    do_stuff("problems",depth,files,group,path,solutions,answers_dir)
    print "\\vfill" # end of chapter, prevent ugly whitespace
  end
end

def main()
  $original_dir = Dir.getwd
  $credits_tex = "\\input{../credits_header.tex}"
  $credits = get_json_data_from_file_or_die($original_dir+"/../photocredits.json")
  $save_meta = {}
  book_config = get_json_data_from_file_or_die("#{$original_dir}/this.config")
  title = book_config["title"]
  solutions = get_problems_data($original_dir+"/../../data/problems.csv")
  answers_dir = $original_dir+"/../../share/answers"
  print <<-'TOP'
    \documentclass{problems}
    \begin{document}
    TOP
  print slurp_or_die($original_dir+"/front_matter.tex").gsub!(/__title__/) {title}
  ["text","hints","answers"].each { |what| # there is also "problems", which is triggered after the text for a chapter
    do_stuff(what,0,'','',[],solutions,answers_dir)
  }
  print $credits_tex
  print <<-'BOTTOM'
    \input{../postamble.tex}
    \end{document}
    BOTTOM
end

main()
