$KCODE = 'u'

$LOAD_PATH.unshift('../lib')
require 'redcloth'

HEADER = <<EOS
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="en-US">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <meta http-equiv="Content-Language" content="en-US">
  <link rel="stylesheet" type="text/css" href="rhg.css">
  <title>$tag(title)$</title>
</head>
<body>
EOS

FOOTER = <<EOS
<hr>

The original work is Copyright &copy; 2002 - 2004 Minero AOKI.<br>
Translated by $tag(translated by)$<br>
<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/2.5/"><img alt="Creative Commons License" border="0" src="http://creativecommons.org/images/public/somerights20.png"/></a><br/>This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/2.5/">Creative Commons Attribution-NonCommercial-ShareAlike2.5 License</a>.

</body>
</html>
EOS

$tags = {}

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
TranslatedByRE = /^Translated by (.+)$/

def generate_html htmlfile, txtfile
  r = RHGRedCloth.new(IO.read(txtfile))

  if md = TranslatedByRE.match(r)
    $tags['translated by'] = md[1]
    r.sub!(TranslatedByRE, '')
  else
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

if __FILE__ == $0
  script_mod_time = File.mtime($0)
  
  Dir.glob("*.txt").each do |file|
    next unless /\.txt$/.match(file)
    html = file.sub(/txt$/, 'html')
    # do not regenerate if the HTML file is newer and this script has not been modified
    next if File.exist?(html) and File.mtime(file) < File.mtime(html) and script_mod_time < File.mtime(html)
    generate_html(html, file)
  end
end
