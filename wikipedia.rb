#!/usr/bin/env ruby
# Wikipedia API -> code_swarm event log
# by Jamie Wilkinson <http://jamiedubs.com>
require 'rubygems'
require 'uri'
require 'mechanize'


def page_history(page, offset = '')
  STDERR.print "#{offset}.. "; STDERR.flush
  
  rvlimit = 500 # revisions per page
  url = "http://en.wikipedia.org/w/api.php?action=query&prop=revisions&titles=#{URI.escape(page)}&rvprop=timestamp|user&rvlimit=#{rvlimit}&format=xml"
  url += "&rvstartid=#{offset}" unless offset.empty?

  agent = WWW::Mechanize.new # FIXME, don't always need to reinitialize 
  doc = Hpricot.XML(agent.get(url).body)
  revisions = (doc/'rev').map { |rev| 
    # STDERR.puts rev['timestamp']
    {:filename => page, :date => Time::parse(rev['timestamp']).to_i*1000, :author => rev['user'] } 
  } || []

  rvstartid = (doc/'query-continue'/'revisions')[0]['rvstartid'] rescue nil
  revisions += page_history(page, rvstartid) || [] if rvstartid
  return revisions
rescue
  STDERR.puts "Exception: #{$!}\n\t#{$!.backtrace.join('\n\t')}"
#ensure
  return revisions
end

def user_history(username, offset = '')
  rvlimit = 500 # revisions per page
  url = "http://en.wikipedia.org/w/index.php?title=Special:Contributions&limit=#{rvlimit}&target=Jamiew"
  url += "&offset=#{offset}" unless offset.empty?
  agent = WWW::Mechanize.new
  agent.user_agent_alias = "Mac Safari"
  doc = agent.get(url)
  revisions = (doc/'#bodyContent li').map { |li| 
    
    # links = (li/'a').delete rescue (print ".")
    # puts links.inspect if links
    filename = li.search('a').remove[2].innerHTML
    # filename = links[2].innerHTML
    comment = (li/'span').remove
    date = li.innerHTML.split('(')[0][0..-2]
    username = username.gsub('User:','')
    
    # puts (li/'span').delete 
    # {:filename => (li
    
    
    { :filename => filename, :date => Time::parse(date).to_i*1000, :author => username }    
  }.sort_by { |f| f[:date] }

  # puts (doc/'a.mw-nextlink').inspect  

  link = (doc/'.mw-nextlink')[0]['href'] rescue nil
  STDERR.puts link.inspect
  
  rvstartid = link.match('.*offset=(.*)\&.*')[1] rescue nil
  revisions += user_history(username, rvstartid) || [] if rvstartid
  return revisions
end




# parse inputs
if ARGV.empty? || ARGV.first.empty?
  puts "#{ARGV[0] }: specify page(s) as parameters (remember to quote 'Barack Obama')"
  exit 1
end
pages = [*ARGV]

STDERR.puts "Building revhistory for #{pages.inspect}..."
puts '<?xml version="1.0"?>'
puts '<file_events>'
revisions = []
pages.each { |page|
  STDERR.puts "\n#{page}"
  revisions += (page =~ /^User\:.*/ ? user_history(page) : page_history(page))
}

revisions.sort_by { |r| r[:date] }.each { |rev|
  # code_swarm wants unixtime in milliseconds
  puts %{<event date="#{rev[:date]}" filename="#{rev[:filename]}" author="#{rev[:author]}" />}
}
puts '</file_events>'
exit 0
