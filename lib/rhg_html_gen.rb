# -*- coding: utf-8 -*- vim:set encoding=utf-8:
$KCODE = 'u'

require 'redcloth'
require 'fileutils'

$tags = {}

HEADER = <<EOS
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="en-US">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <meta http-equiv="Content-Language" content="#{ISOLanguage}">
  <link rel="stylesheet" type="text/css" href="rhg.css">
  <title>$tag(title)$</title>
</head>
<body>
EOS

class RHGRedCloth < RedCloth
  # adds a caption below images
  # (and removes `code marks` for the title and alt attributes)
  def refs_add_image_title(text)
    fig_counter = 0
    text.gsub!(IMAGE_RE) do |m|
      fig_counter += 1
      stln,algn,atts,url,title,href,href_a1,href_a2 = $~[1..8]
      puts "Warning: the images used the the RHG should be PNGs, not JPEGs" if /\.jpe?g$/i.match(url)
      "\n\np=. #{m.gsub(/`/, '')}<br>Figure #{fig_counter}: #{title}\n\n"
    end
  end
  
  # creates links automatically
  # note: the character before must not be ":" not to replace any already existing link like "Text":http://link/nantoka
  AUTOLINK_RE = %r{(^|[^:])\b((?:ht|f)tp://\S+?)([^\w\/;]*?)(?=\s|<|$)}
  def inline_autolink(text)
    text.gsub!(AUTOLINK_RE) do |m|
      before, address, after = $~[1..3]
      "#{before}\"#{address}\":#{address}#{after}"
    end
  end

  # manages includes
  INCLUDE_RE = /\$include\((.+?)\)\$/
  def refs_include(text, already_included = [])
    text.gsub!(INCLUDE_RE) do |m|
      file = $~[1]
      raise "Error: recursive inclusion of #{file} detected" if already_included.include?(file)
      raise "Error: can't find included file #{file}" unless File.exists?(file)
      content = IO.read(file)
      refs_include(content, [ already_included, file ].flatten)
      incoming_entities content
      clean_white_space content
      content
    end
  end
  
  # manages comments
  COMMENT_RE = /\$comment\((.+?)\)\$/
  def refs_comment(text)
    text.gsub!(COMMENT_RE) { |m| '' }
  end
  
  # manages tags
  TAG_RE = /\$tag\((.+?)\)\$/
  def self.replace_tags(text)
    text.gsub(TAG_RE) do |m|
      tag_name = $~[1]
      if $tags[tag_name]
        $tags[tag_name]
      else
        puts "Warning: The tag #{tag_name} is not defined"
        ''
      end
    end
  end

  def refs_tag(text)
    self.replace(self.class.replace_tags(text))
  end
  
  # adds a new type of code statement
  # contrary to the standard one of textile,
  # this one can have code on multiple lines
  # and can be followed just after by any character
  # (no need for a space or punctuation)
  NEW_CODE_RE = /`(.*?)`/m
  def inline_textile_new_code(text)
    text.gsub!(NEW_CODE_RE) { |m| rip_offtags("<code>#{$~[1]}</code>") }
  end
end

RedClothRules = [ :refs_comment, :refs_tag, :refs_include, :refs_add_image_title, :inline_autolink, :inline_textile_new_code, :textile ]

def generate_html htmlfile, txtfile
  r = RHGRedCloth.new(IO.read(txtfile))

  if md = TranslatedByRE.match(r)
    $tags['translated by'] = md[1]
    r.sub!(TranslatedByRE, '')
  elsif not $tags['translated by']
    STDERR.puts "error: no translator defined in file #{txtfile}"
    return
  end

  if md = /h1\.\s*(.+)$/.match(r)
    $tags['title'] = md[1].gsub(/(<[^>]*>|`)/, '') # remove markup and backquotes from the title
  else
    STDERR.puts "error: no h1 section in file #{txtfile}"
    return
  end
  
  File.open(htmlfile, 'w') do |io|
    puts "Generating '#{$tags['title']}' - #{htmlfile}..."
    io.write(RHGRedCloth.replace_tags(HEADER))
    io.write(r.to_html(*RedClothRules))
    io.write(RHGRedCloth.replace_tags(FOOTER))
  end 
end

def make(*options)
  script_mod_time = [ File.mtime($0), File.mtime(__FILE__) ].max
  
  Dir.glob("*.txt").each do |file|
    next unless /\.txt$/.match(file)
    html = file.sub(/txt$/, 'html')
    # do not regenerate if the HTML file is newer and this script has not been modified
    next if File.exist?(html) and File.mtime(file) < File.mtime(html) and script_mod_time < File.mtime(html)
    generate_html(html, file)
  end
  
  if options.include?('--make-zip')
    dest_dir = "rhg-#{$tags['language']}-#{$tags['generation day']}"
    dest_zip = "#{dest_dir}.zip"
    FileUtils.rm_r(dest_dir, :force => true)
    
    to_process = [ 'index.html' ]
    to_process.each do |file_name|
      dir = File.dirname(file_name)
      if dir == '.' then dir = dest_dir else dir = "#{dest_dir}/#{dir}" end
      FileUtils.mkdir_p(dir)
      FileUtils.cp(file_name, dir)

      next unless /\.html/.match(file_name)

      content = IO.readlines(file_name).join
      content.scan(%r{<(?:a|img|link)\b[^>]*?\b(?:href|src)="(.+?)"}) do |found_file,|
        to_process << found_file unless %r{^(/|http://)}.match(found_file) or to_process.include?(found_file)
      end
    end
    FileUtils.rm(dest_zip, :force => true)
    if system("zip -r9 #{dest_zip} #{dest_dir}")
      FileUtils.rm_r(dest_dir, :force => true)
    else
      STDERR.puts "error when trying to zip files"
      exit 1
    end
  end
end
