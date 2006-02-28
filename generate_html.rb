require 'rubygems'
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
</body>
</html>
EOS

Dir.glob("*.txt").each do |file|
    next unless /\.txt$/.match(file)
    
    r = RedCloth.new(IO.read(file))
    title = if md = /h1\.\s*(.+)$/.match(r)
        md[1]
    else
        $STDERR.puts "no h1 section on file #{file}"
        exit 1
    end
    html = file.sub(/txt$/, 'html')
    File.open(html, 'w') do |io|
        puts "Generating '#{title}' - #{html}..."
        io.write(HEADER.sub('TITLE', title))
        io.write(r.to_html)
        io.write(FOOTER)
    end 
end
