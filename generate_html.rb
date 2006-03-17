$KCODE = 'u'

begin
  require 'rubygems'
rescue LoadError
end
require 'redcloth'

HEADER = <<EOS
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="en-US">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <meta http-equiv="Content-Language" content="en-US">
  <link rel="stylesheet" type="text/css" href="rhg.css">
  <title>TITLE</title>
</head>
<body>
EOS

FOOTER = <<EOS
<hr>

The original work is Copyright &copy; 2002 - 2004 Minero AOKI.<br>
Translation by TRANSLATION_BY<br>
<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/2.5/"><img alt="Creative Commons License" border="0" src="http://creativecommons.org/images/public/somerights20.png"/></a><br/>This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/2.5/">Creative Commons Attribution-NonCommercial-ShareAlike2.5 License</a>.

</body>
</html>
EOS

class RedCloth
  # adds a caption below images
  def inline_add_image_title(text)
    fig_counter = 0
    text.gsub!(IMAGE_RE) do |m|
      fig_counter += 1
      stln,algn,atts,url,title,href,href_a1,href_a2 = $~[1..8]
      "#{m}<br>Diagram #{fig_counter}: #{title}"
    end
  end
  
  # creates links automatically
  AUTOLINK_RE = %r{(\s|^)((?:ht|f)tp://\S+?)([^\w\/;]*?)(?=\s|<|$)}
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

RedClothRules = [ :refs_include, :inline_add_image_title, :inline_autolink, :inline_textile_new_code, :textile ]

script_mod_time = File.mtime($0)

TranslationByRE = /^Translation by (.+)$/

Dir.glob("*.txt").each do |file|
  next unless /\.txt$/.match(file)
  
  r = RedCloth.new(IO.read(file))

  if md = TranslationByRE.match(r)
    translation_by = md[1]
    r.sub!(TranslationByRE, '')
  else
    STDERR.puts "error: no translator defined in file #{file}"
    next
  end

  if md = /h1\.\s*(.+)$/.match(r)
    title = md[1]
  else
    STDERR.puts "error: no h1 section in file #{file}"
    next
  end
  
  html = file.sub(/txt$/, 'html')
  # do not regenerate if the HTML file is newer and this script has not been modified
  next if File.exist?(html) and File.mtime(file) < File.mtime(html) and script_mod_time < File.mtime(html)
  File.open(html, 'w') do |io|
    puts "Generating '#{title}' - #{html}..."
    io.write(HEADER.sub('TITLE', title))
    io.write(r.to_html(*RedClothRules))
    io.write(FOOTER.sub('TRANSLATION_BY', translation_by))
  end 
end
