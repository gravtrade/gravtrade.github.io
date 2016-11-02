#!/usr/bin/env ruby
# -*- coding: utf-8 -*- #specify UTF-8 (unicode) characters

#Email to Jekyll script
#(c)2011 Ted Kulp <ted@tedkulp.com> 
# Portions copyright 2011 masukomi <masukomi@masukomi.org>
# POP3 support and Git config integration added by masukomi
#MIT license -- Have fun
#Most definitely a work in progress

# TODO
# error handling:
# - complain if any of the required blog are not defined

require 'rubygems'
require 'yaml'
require 'net/pop'
require 'mail'
require 'nokogiri'
require 'fileutils'
#require 'grit'
#include Grit


DEBUG = false
DELETE_AFTER_RUN = true

#JEKYLLMAIL_USER= Actor.from_string("JekyllMail Script <jekyllmail@masukomi.org>")


directory_keys = ['jekyll_repo', 'source_dir', 'site_url']
yaml = YAML::load(File.open('_config.yml'))
blogs = yaml['blogs']
blogs.each do | blog | 
	# the blog hash contains
	# jekyll_repo => absolute path to the root of the jekyll repo
	# source_dir => absolute path to the directory containing _posts, _drafts, and images
	# pop_server => domain name
	# pop_user => username
	# pop_password => plaintext password
	# secret => the secret that must appear in the email subject
	# markup => markup or textile
	# site_url => the http://.... url to the root of the public web site
	# commit_after_save => boolean
	# git_branch => the name of the git branch to commit to
	## git_branch is Unused until we get Grit working correctly

	directory_keys.each do | key |
		blog[key].sub!(/\/$/, '') # remove any trailing slashes from directory paths
		puts "#{key}: #{blog[key]}" if DEBUG
	end
	blog['images_dir'] ||= 'images' #relative to site_url
	blog['posts_dir'] ||= '_posts' #relative to source_dir


	Mail.defaults do
	  retriever_method :pop3, :address    => blog['pop_server'],
							  :port       => 995,
							  :user_name  => blog['pop_user'],
							  :password   => blog['pop_password'],
							  :enable_ssl => true
	end

	emails = Mail.all

	if (emails.length == 0 )
		puts "No Emails found" if DEBUG
		next #move on to the next blog's config
	else
		puts "#{emails.length} email(s) found" if DEBUG
	end



	emails.each do | mail |
		files_to_commit = []
		markup_extensions = {:html => 'html', :markdown => 'markdown', :md => 'markdown', :textile => 'textile', :txt => 'textile'}
		keyvals = {:tags => '', :markup => blog['markup'], :slug => '', :published => true, :layout => 'post'}
		subject = mail.subject
		puts "processing email with subject: #{subject}" if DEBUG

		#If there is no working subject, bail
		next if subject.empty?
		
		# <subject> || key: value / key: value / key: value, value, value
		(title, raw_data) = subject.split(/\|\|/) # two pipes separate subject from data
		title.gsub!(/^\s+|\s+$/, '')
		unless raw_data.nil?
			datums = raw_data.split('/')
			datums.each do |datum|
				next if datum.nil?
				(key, val) = datum.split(/:\s?/)
				key.gsub!(/\s+/, '')
				val.gsub!(/\s+$/, '')
				keyvals[key.to_sym] = val
			end
		end
		
		
		# if it doesn't contain the secret we can assume it to be spam
		next unless keyvals[:secret] == blog['secret']

		keyvals.delete(:secret) # we don't want that in the post's Frontmatter
		slug = title.gsub(/[^[:alnum:]]+/, '-').downcase.strip.gsub(/\A\-+|\-+\z/, '')
		time = Time.now
		name = "%02d-%02d-%02d-%s.%s" % [time.year, time.month, time.day, slug, markup_extensions[keyvals[:markup].to_sym]]

		
		#TODO figure out a better way to integrate hashtag 
		# support or removal: 
		# - Maybe they should be converted to tags?
		# - Maybe they should be killed?
		#Now remove any hash tags (like from Instagram)
		#title = title.gsub(/ \#\w+/, '').strip

		body = ''
		
		images_needing_replacement = {} #maps filename to public url file will be served from
		#Is this multipart?
		if mail.multipart?
			html_part = -1
			txt_part = -1

			#Figure out which part is html and which
			#is text
			mail.parts.each_with_index do |p,idx|
				if p.content_type.start_with?('text/html')
					html_part = idx
				elsif p.content_type.start_with?('text/plain')
					txt_part = idx
				end
			end

			mail.attachments.each do |attachment|
				#TODO: break this out into a separate method.
				if (attachment.content_type.start_with?('image/'))
					fn = attachment.filename
					images_dir = blog['images_dir'] + ("/%02d/%02d/%02d" % [time.year, time.month, time.day])
					local_images_dir = "#{blog['source_dir']}/#{images_dir}"
					puts "local_images_dir: #{local_images_dir}"
					images_needing_replacement[fn] = "#{blog['site_url']}/#{images_dir}/#{fn}"
					puts "image url: #{images_needing_replacement[fn]}"
					unless Dir.exists?(local_images_dir)
						puts "creating dir #{local_images_dir}" if DEBUG
						FileUtils.mkdir_p(local_images_dir)
					end
					begin
						local_filename = "#{blog['source_dir']}/#{images_dir}/#{fn}"
						puts "saving image to #{local_filename}" if DEBUG
						unless File.writable?(local_images_dir)
							$stderr.puts("ERROR: #{local_images_dir} is unwritable. Exiting.")
						end
						File.open( local_filename, "w+b", 0644 ) { |f| f.write attachment.body.decoded }
						files_to_commit << "source/#{images_dir}/#{fn}"
					rescue Exception => e
						$stderr.puts "Unable to save data for #{fn} because #{e.message}"
					end
				end
			end
					

			#If the markup isn't html, try and use the
			#text if it exists. Anything else, use the html
			#version
			if txt_part > -1 and keyvals[:markup] != 'html'
				body = mail.parts[txt_part].body.decoded
			elsif html_part > -1
				body = mail.parts[html_part].body.decoded
			end
		else
			#Just grab the body no matter what it is
			body = mail.body.decoded
		end

		#If we have no body after all that, bail
		exit if body.strip.empty?

		#If it's html, run it through nokogiri to make sure it's clean
		if keyvals[:markup] == 'html'
			#body.gsub!(/[”“]/, '"')
			#body.gsub!(/[‘’]/, "'")
			body = Nokogiri::HTML::DocumentFragment.parse(body.strip).to_html
		end
		if (images_needing_replacement.length() > 0)
			#TODO break this out into a method for testability
			images_needing_replacement.each do | filename, path |
				if keyvals[:markup] == 'markdown'
					body.gsub!(/(\(|\]:\s|<)#{Regexp.escape(filename)}/, "\\1#{path}")
				elsif keyvals[:markup] == 'textile'
					body.gsub!(/!#{Regexp.escape(filename)}(!|\()/, "!#{path}\\1")
				elsif keyvals[:markup] == 'html'
					body.gsub!(/(src=(?:'|")|href=(?:'|"))#{Regexp.escape(filename)}/i, "\\1#{path}")
					# WARNING: won't address urls in css
					# Is case insensitive so it won't differentiatee FOO.jpg from foo.jpg or FoO.jpg
					# people shouldn't be using the same name for different files anyway. :P
				end
			end
		end

		post_filename =  "#{blog['source_dir']}/#{blog['posts_dir']}/#{name}"

		if File.writable?("#{blog['source_dir']}/#{blog['posts_dir']}")
			puts "saving post to #{post_filename}" if DEBUG
		else
			$stderr.puts "ERROR: #{blog['source_dir']}/#{blog['posts_dir']} is not writable"
			exit 0
		end
		open(post_filename, 'w') do |str|
			str << "---\n"
			str << "title: '#{title}'\n"
			str << "date: %02d-%02d-%02d %02d:%02d:%02d\n" % [time.year, time.month, time.day, time.hour, time.min, time.sec]
			keyvals.keys.sort.each do |key|
				if key != :tags  and key != :slug
					str << "#{key}: #{keyvals[key]}\n"
				elsif key == :tags
					unless keyvals[:tags].empty?
						str << "tags: \n"
						keyvals[:tags].split(',').each do |string|
							str << "- " + string.strip + "\n"
						end
					end
				end
			end
			str << "---\n"
			str << body
		end
		files_to_commit << post_filename

		if blog['commit_after_save'] and files_to_commit.size() > 0
			# NOTES for devs
# @repo = Repo.new(blog['jekyll_repo'])
#     index = @repo.index
#     index.add('foo/bar/baz.txt', 'hello!')
#     index.commit('first commit')
	#	possibly Dir.chdir('repo/test.git') { jekyll_repo.add('foo.txt') }

			#repo = Grit::Repo.new(blog['jekyll_repo'])
			#parents = [repo.commits.first]
			#index = repo.index
			
			Dir.chdir(blog['jekyll_repo']) #probably unnecessary
			files_to_commit.each do |file|
				relative_file_name = file.sub(/.*?source\//, 'source/')
				puts "adding #{relative_file_name}" if DEBUG
				#index.add(relative_file_name, open(file, "rb") {|io| io.read })
							#repo_specific_file_name, binary_data
				`git add #{relative_file_name}`
			end
			puts "committing" if DEBUG
			#sha = index.commit("Adding post #{slug} via JekyllMail", parents, JEKYLLMAIL_USER, nil, blog['git_branch'])
			#puts "sha = #{sha}" if DEBUG
			`git commit -m "Adding post #{slug} via JekyllMail"`
		end


	end

	Mail.delete_all() unless DEBUG == true or DELETE_AFTER_RUN == false
		# when debugging it's much easier to just leave the emails there and re-use them

end
