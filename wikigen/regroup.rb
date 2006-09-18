#!/usr/bin/env ruby
# -*- coding: utf-8 -*- vim:set encoding=utf-8:
# TODO:
# - cleanup (and remove dependency with rhg_html_gen)
# - images
# - when generating the output data, if Japanese = English, add in the English something like "(To translate)"
$KCODE = 'u'

ISOLanguage = 'en-US'

$LOAD_PATH.unshift('../lib')
require 'rhg_html_gen'

COMMENT_RE = /\$comment\((.+?)\)\$/
AUTOLINK_RE = %r{(^|[^:])\b((?:ht|f)tp://\S+?)([^\w\/;]*?)(?=\s|<|$)}
NEW_CODE_RE = /`([^<]*?)`/m
TAG_RE = /\$tag\((.+?)\)\$/

AUTO_CONV_ENDING=<<END
<hr>

御意見・御感想・誤殖の指摘などは
"青木峰郎 &lt;aamine@loveruby.net&gt;":mailto:aamine@loveruby.net
までお願いします。

"『Rubyソースコード完全解説』
はインプレスダイレクトで御予約・御購入いただけます (書籍紹介ページへ飛びます)。":http://direct.ips.co.jp/directsys/go_x_TempChoice.cfm?sh_id=EE0040&amp;spm_id=1&amp;GM_ID=1721

Copyright (c) 2002-2004 Minero Aoki, All rights reserved.
END

TranslatedByRE = /^Translated by (.+)$/

def rhg_redcloth_replace(text)
	text = text.dup
  if md = TranslatedByRE.match(text)
    $tags['translated by'] = md[1]
    text.sub!(TranslatedByRE, '')
	end
	text.sub!(AUTO_CONV_ENDING, '') # remove the ending in the automatically generated Japanese files
  text.gsub!(COMMENT_RE) { |m| '' } # remove comments
	text.gsub(TAG_RE) do |m| # manages tags
		tag_name = $~[1]
		if $tags[tag_name]
			$tags[tag_name]
		else
			puts "Warning: The tag #{tag_name} is not defined"
			''
		end
  end
	fig_counter = 0
	text.gsub!(RedCloth::IMAGE_RE) do |m| # must be done before the `` replacement
		fig_counter += 1
		stln,algn,atts,url,title,href,href_a1,href_a2 = $~[1..8]
		#puts "Warning: the images used the the RHG should be PNGs, not JPEGs" if /\.jpe?g$/i.match(url)
		"\n\n<p style=\"text-align:center;\">\n#{m.gsub(/`/, '')}<br />Figure #{fig_counter}: #{title}\n</p>\n\n"
	end
  text.gsub!(NEW_CODE_RE) { |m| "<code>#{$~[1]}</code>" }
	text.gsub!(AUTOLINK_RE) do |m|
		before, address, after = $~[1..3]
		"#{before}\"#{address}\":#{address}#{after}"
	end
	text
end

class Blocks
	def initialize(filename)
		@data = rhg_redcloth_replace(IO.read(filename)).split(/\n/).map { |l| l.rstrip }
		@boundaries = []

		find_boundaries
	end

	def length
		@boundaries.length
	end

	def [](i)
		@data[@boundaries[i]].join("\n")
	end

	def regroup_with_following(i)
		@data[@boundaries[i].last] << "\n<==================================>"
		@boundaries[i] = @boundaries[i].first..@boundaries[i+1].last
		@boundaries.delete_at(i+1)
	end

	def each
		length.times { |i| yield self[i] }
	end

private
	def find_boundaries
		beginning = 0
		in_pre = false
		@data.each_with_index do |line, i|
			if line.empty? and not in_pre
				if i != beginning
					@boundaries.push(beginning..(i-1))
					beginning = i+1
				else
					beginning += 1
				end
			elsif i == @data.length - 1
				@boundaries.push(beginning..i)
			elsif /<pre/.match(line)
				@boundaries.push(beginning..(i-1)) if i > beginning
				beginning = i
				in_pre = true
			elsif /<\/pre/.match(line)
				@boundaries.push(beginning..i)
				beginning = i+1
				in_pre = false
			end
		end
	end
end

chapter_num = sprintf("%02d", ARGV[0].to_i)

en_file_name = "../en/chapter#{chapter_num}.txt"
ja_file_name = "../ja/chapter#{chapter_num}.txt"
# if the English file does not exist yet, just use the Japanese one as source
if File.exists?(en_file_name)
  blocks_en = Blocks.new(en_file_name)
else
  $tags['translated by'] = '(not translated yet)'
  blocks_en = Blocks.new(ja_file_name)
end
blocks_ja = Blocks.new(ja_file_name)

BLOCK_REGROUPING_RE = /^(h[1-9]\.|<pre|▼)/

i = 0
regroup_pos = 0
while i < blocks_ja.length and i < blocks_en.length
	block_ja = blocks_ja[i]
	block_en = blocks_en[i]
	if BLOCK_REGROUPING_RE.match(block_ja)
		if BLOCK_REGROUPING_RE.match(block_en)
			regroup_pos = i
			i += 1
		else
			blocks_en.regroup_with_following(regroup_pos)
		end
	elsif BLOCK_REGROUPING_RE.match(block_en)
		blocks_ja.regroup_with_following(regroup_pos)
	else
		i += 1
	end
end

# regroup the last blocks to have the same number of blocks in both
blocks_en.regroup_with_following(blocks_en.length-2) while blocks_ja.length < blocks_en.length
blocks_ja.regroup_with_following(blocks_ja.length-2) while blocks_en.length < blocks_ja.length

blocks_en.each do |b|
	if md = /h1\.\s*(.+)$/.match(b)
    $tags['title'] = md[1].gsub(/(<[^>]*>|`)/, '') # remove markup and backquotes from the title
		break
  end
end
if not $tags['title']
	STDERR.puts "error: no h1 section in source file"
	return
end

File.open("chapter#{chapter_num}.txt", "w") do |f|
	f.puts "<table>"
	blocks_ja.length.times do |i|
		f.puts "<tr><td>"
		f.puts
		f.puts blocks_en[i]
		f.puts
		f.puts "</td><td>"
		f.puts
		f.puts blocks_ja[i]
		f.puts
		f.print "</td></tr>"
	end
	f.puts
	f.puts "</table>"
end

FOOTER = <<EOS
<hr>

The original work is Copyright &copy; 2002 - 2004 Minero AOKI.<br />
Translated by #{$tags['translated by']}<br />
<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/2.5/"><img alt="Creative Commons License" border="0" src="images/somerights20.png"/></a><br/>This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/2.5/">Creative Commons Attribution-NonCommercial-ShareAlike2.5 License</a>.

</body>
</html>
EOS

RedClothRules = [ :textile ]

generate_html("chapter#{chapter_num}.html", "chapter#{chapter_num}.txt")
