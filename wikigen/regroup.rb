#!/usr/bin/env ruby
# -*- coding: utf-8 -*- vim:set encoding=utf-8:
# TODO:
# - cleanup
# - images
# - when generating the output data, if source language = destination language, add in the destination language something like "(to translate)" (and make it depend on the language)
$KCODE = 'u'

$LOAD_PATH.unshift('../lib')
require 'redcloth'
require 'yaml'

Languages = YAML::load(IO.read('languages.yml'))
AvailableDestinationLanguages = Languages.keys.select { |lang| Languages[lang][:can_be_destination_language] }.sort
AvailableSourceLanguages = Languages.keys.sort

def syntax
	puts "syntax: #{$0} source_language destination_language chapter_number"
	puts "where the source language is one of the following: #{AvailableSourceLanguages.join(', ')}"
	puts "and the destination language is one of the following: #{AvailableDestinationLanguages.join(', ')}"
	exit 1
end

syntax if ARGV.length != 3 or not AvailableSourceLanguages.include?(ARGV[0]) or not AvailableDestinationLanguages.include?(ARGV[1]) or ARGV[2].to_i == 0
src_lang = ARGV[0]
dst_lang = ARGV[1]
chapter_num = ARGV[2].to_i

$tags = {}

HEADER = <<EOS
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="#{Languages[dst_lang][:iso_language]}">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <meta http-equiv="Content-Language" content="#{Languages[dst_lang][:iso_language]}">
  <link rel="stylesheet" type="text/css" href="rhg.css">
  <title>$tag(title)$</title>
</head>
<body>
EOS
FOOTER = Languages[dst_lang][:footer]

COMMENT_RE = /\$comment\((.+?)\)\$/
AUTOLINK_RE = %r{(^|[^:])\b((?:ht|f)tp://\S+?)([^\w\/;]*?)(?=\s|<|$)}
NEW_CODE_RE = /`([^<]*?)`/m
TAG_RE = /\$tag\((.+?)\)\$/
BLOCK_REGROUPING_RE = /^(h[1-9]\.|<pre\b|<p\b|▼)/

# manages tags
def replace_tags(text)
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

AUTO_CONV_ENDING=<<END
<hr>

御意見・御感想・誤殖の指摘などは
"青木峰郎 &lt;aamine@loveruby.net&gt;":mailto:aamine@loveruby.net
までお願いします。

"『Rubyソースコード完全解説』
はインプレスダイレクトで御予約・御購入いただけます (書籍紹介ページへ飛びます)。":http://direct.ips.co.jp/directsys/go_x_TempChoice.cfm?sh_id=EE0040&amp;spm_id=1&amp;GM_ID=1721

Copyright (c) 2002-2004 Minero Aoki, All rights reserved.
END

class Blocks
	def initialize(filename, lang, is_destination_lang)
		@lang = lang
		@is_destination_lang = is_destination_lang
		@data = rhg_redcloth_replace(filename)

		@boundaries = []
		find_boundaries
	end

	def length
		@boundaries.length
	end

	def [](i)
		@data[@boundaries[i]].join("\n")
	end

	def each_from(i)
		i.upto(self.length-1) { yield self[i] }
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

	# transforms the modified RHG RedCloth syntax to normal RedCloth
	# and returns an array of lines (without end of lines)
	def rhg_redcloth_replace(filename)
		text = IO.read(filename)
		translated_by_re = Languages[@lang][:translated_by_re] # note: translated_by_re is not defined for Japanese
		if translated_by_re and md = translated_by_re.match(text)
			$tags['translated by'] = md[1] if @is_destination_lang
			text.sub!(translated_by_re, '')
		end
		text.sub!(AUTO_CONV_ENDING, '') if @lang == 'ja' # remove the ending in the automatically generated Japanese files if it's there
		text.gsub!(COMMENT_RE) { |m| '' } # remove comments
		text = replace_tags(text)
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
		text.split(/\n/).map { |l| l.rstrip }
	end
end

dst_lang_file_name = "../#{dst_lang}/#{sprintf(Languages[dst_lang][:chapter_name], chapter_num)}"
src_lang_file_name = "../#{src_lang}/#{sprintf(Languages[src_lang][:chapter_name], chapter_num)}"

blocks_src_lang = Blocks.new(src_lang_file_name, src_lang, false)
# if the file in the destination language does not exist yet, just use the one in the source language as source
if File.exists?(dst_lang_file_name)
  blocks_dst_lang = Blocks.new(dst_lang_file_name, dst_lang, true)
else
	puts "warning: the translation is not available for this chapter"
  blocks_dst_lang = Blocks.new(src_lang_file_name, src_lang, false)
  $tags['translated by'] = Languages[dst_lang][:not_translated]
end

# the following code tries to have as many blocks of text in each language
# it searches for anchors (defined by the BLOCK_REGROUPING_RE regexp) and tries to aligns the anchors in both languages
i = 0
regroup_pos = 0
while i < blocks_src_lang.length and i < blocks_dst_lang.length
	block_src_lang = blocks_src_lang[i]
	block_dst_lang = blocks_dst_lang[i]
	if md_src = BLOCK_REGROUPING_RE.match(block_src_lang)
		if md_dst = BLOCK_REGROUPING_RE.match(block_dst_lang)
			if md_src[0] != md_dst[0]
				# if the anchors found at the current position are different in the two languages,
				# we search for the next anchor to know which side is the more likely to need a regroupment
				next_md_src = nil
				next_md_dst = nil
				blocks_src_lang.each_from(i+1) { |block| break if next_md_src = BLOCK_REGROUPING_RE.match(block) }
				blocks_dst_lang.each_from(i+1) { |block| break if next_md_dst = BLOCK_REGROUPING_RE.match(block) }
				if next_md_src and next_md_src[0] == md_dst[0]
					blocks_src_lang.regroup_with_following(regroup_pos)
				elsif next_md_dst and next_md_dst[0] == md_src[0]
					blocks_dst_lang.regroup_with_following(regroup_pos)
				else
					i += 1
					regroup_pos = i
				end
			else
				i += 1
				regroup_pos = i
			end
		else
			blocks_dst_lang.regroup_with_following(regroup_pos)
		end
	elsif md_dst = BLOCK_REGROUPING_RE.match(block_dst_lang)
		blocks_src_lang.regroup_with_following(regroup_pos)
	else
		i += 1
	end
end

# regroup the last blocks to have the same number of blocks in both
blocks_dst_lang.regroup_with_following(blocks_dst_lang.length-2) while blocks_src_lang.length < blocks_dst_lang.length
blocks_src_lang.regroup_with_following(blocks_src_lang.length-2) while blocks_dst_lang.length < blocks_src_lang.length

blocks_dst_lang.each do |b|
	if md = /h1\.\s*(.+)$/.match(b)
		$tags['title'] = md[1].gsub(/(<[^>]*>|`)/, '') # remove markup and backquotes from the title
		break
	end
end
if not $tags['title']
	STDERR.puts "error: no h1 section in the file in the destination language"
	return
end

base_file_name = sprintf("chapter%02d_#{src_lang}_#{dst_lang}", chapter_num)
html_file = "#{base_file_name}.html"
redcloth_file = "#{base_file_name}.redcloth.txt"

redcloth_text = '<table>'
blocks_src_lang.length.times do |i|
	redcloth_text << "<tr><td>\n\n#{blocks_dst_lang[i]}\n\n</td>"
	redcloth_text << "<td>\n\n#{blocks_src_lang[i]}\n\n</td></tr>\n"
end
redcloth_text << "\n</table>\n"

File.open(redcloth_file, "w") do |f| f.puts redcloth_text end

r = RedCloth.new(redcloth_text)

File.open(html_file, 'w') do |io|
	puts "Generating '#{$tags['title']}' - #{html_file}..."
	io.write(replace_tags(HEADER))
	io.write(r.to_html)
	io.write(replace_tags(FOOTER))
end 
