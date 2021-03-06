require 'time'
require 'kramdown'
require 'sinatra/base'
require 'redcloth'
require 'thin'
require 'thin/prefork'
require 'builder'
require 'htmlentities'
require 'flickraw'
require 'rss/maker'
require 'uri'
load "config.rb"

class Myway < Sinatra::Base;end
require 'my-way/page'

class Myway
  module NamedArgs
    def set_attr_from_hash(args)
      args.each {|k,v|
        k="#{k}=".to_sym; self.public_methods.include?(k) and self.send(k,v)
      }
    end
  end

  class Formatter
    def initialize(string)
      @string=string
    end
    def flickr_link(id,attr)
      info=flickr.photos.getInfo(:photo_id=>id)
      link=FlickRaw.url_photopage(info)
      src=FlickRaw.url_m(info)
      %Q{<a href="#{link}"><img #{attr} class="flickr" src="#{src}" /></a>}
    end

  end

  class Formatter::Markdown < Formatter
    def to_html
      Kramdown::Document.new(@string).to_html
    end
  end
  class Formatter::Textile < Formatter
    module NewTags
      def tweet(opts)
        user,id,txt=opts[:text].split(/ /,3)
        Erector.inline do
          div :class=>:tweet do
            div :class=>:body do
              rawtext txt
            end
            div :class=>:link do
              a "from twitter",
              :href=>"http://twitter.com/#{user}/statuses/#{id}"
            end
          end
        end.to_html
      end
    end
    def to_html
      string=@string.gsub(/!F([<>]?)(.*?)!/) { |txt|
        case $1
        when ?> then float="style='float: right'" ; txt=txt[1..-1].strip
        when ?< then float="style='float: left'" ; txt=txt[1..-1].strip
        else float=''
        end
        id=($2 || $1).to_i
        flickr_link(id,float)
      }

      rc=::RedCloth.new(string)
      rc.extend(NewTags)
      rc.hard_breaks=false
      rc.to_html
    end
  end

  class Article
    include NamedArgs
    attr_accessor :subject,:date,:filename,:content_offset,:slug
    def initialize(args)
      set_attr_from_hash(args)
    end
    def markup
      ::Myway::Formatter::Textile
    end
    def self.slug_for_title(title)
      title.gsub(/[^A-Za-z0-9]+/,"_").gsub(/_+$/,"").downcase
    end
    def make_slug
      @slug || self.class.slug_for_title(@subject)
    end
    def url
      "/"+[@date.year,@date.month,@date.day,make_slug].join("/")
    end
  end

  class Blog
    include NamedArgs
    attr_accessor :directory,:articles

    def initialize(args)
      set_attr_from_hash(args)
      rescan
    end

    def rescan
      f=File.join(@directory,"articles","*.{html,md,textile}")
      @articles=Dir.glob(f).reject{|x| %r{/draft-}.match(x) }.map do |f|
        File.open(f) do |fd|
          headers={:filename=>f}
          fd.each_line do |line|
            key,val=line.split(/:/,2)
            unless val then
              headers[:content_offset]=fd.tell
              break
            end
            case key.downcase
            when /subject|title/ then headers[:subject]=val.strip
            when "slug" then headers[:slug]=val.strip
            when "date" then headers[:date]=Time.parse(val)
            when "draft" then headers[:draft]=true
            end
          end
          headers[:slug] ||= Article.slug_for_title(headers[:subject])
          unless headers[:draft] then Article.new headers end
        end
      end
      @articles=@articles.compact.sort_by(&:date)
    end
  end

  def initialize
    super
    @blog=Blog.new(:directory=>"example")
  end

  enable :static
  set :public, File.join(Dir.pwd,'public')
  set :run, false
  set :show_exceptions, false
  attr_accessor :blog

  helpers do
    def entry(request,art,comments=false)
      target=url(art.url)
      Erector.inline do
        div :class=>:entry do
          h2 :class=>:subject do
            a art.subject,:href=>target
            a "#",:href=>target,:class=>:permalink
          end

          h3 art.date.rfc2822, :class=>:date
          File.open(art.filename) do |fd|
            fd.seek(art.content_offset)
            rawtext art.markup.new(fd.read).to_html
          end
          if comments then
            p do
              a art.subject, :href=>"#{art.url}#disqus_thread"
            end
          end

        end
      end
    end
  end

  get '/news.rss' do
    content_type 'application/rss+xml', :charset=>'utf-8'
    recent = @blog.articles
    if recent.length> 10 then recent=recent[-10..-1] end
    feed=RSS::Maker.make("2.0") do |m|
      m.channel.title = "diary at Telent Netowrks"
      m.channel.link = "http://ww.telent.net/"
      m.channel.description = "Geeky stuff about what I do.  By Daniel Barlow"
      m.items.do_sort = true # sort items by date

      recent.each do |a|
        i = m.items.new_item
        i.title = a.subject
        i.link = url(a.url)
        i.guid.content = url(a.url)

        i.description=Erector.inline do
          File.open(a.filename) do |fd|
            fd.seek(a.content_offset)
            rawtext a.markup.new(fd.read).to_html
          end
        end.to_html
        i.author='Daniel Barlow'
        i.date = a.date
      end
    end
    feed.to_s
  end


  get '/' do
    articles= @blog.articles
    recent=articles[-2..-1]
    older=articles[-8..-3]
    Page.new(:title=>"Recent posts",:base=>uri,:blog=>@blog) do
      recent.reverse.each do |art|
        widget entry(request,art,:comment_link)
      end
      div :class=>:adsense_banner do
        rawtext Adsense::Thin_ad
      end
      div :class=>:entry do
        h2 "Older posts"
        ul do
          older.reverse.each do |a|
            li do
              a a.subject,:href=>"#{a.url}"
              text " ("
              a a.subject,:href=>"#{a.url}#disqus_thread",:style=>"text-decoration: none"
              text ") "
              text " "+a.date.strftime("%a, %e %B")
            end
          end
          li do
            date=Time.now
            a date.strftime("Month of %B %Y"),
            :href=> "#{date.year}/#{date.month}/"
          end
        end
      end
      javascript "var disqus_shortname = 'telent';
    (function () {
        var s = document.createElement('script'); s.async = true;
        s.type = 'text/javascript';
        s.src = 'http://' + disqus_shortname + '.disqus.com/count.js';
        (document.getElementsByTagName('HEAD')[0] || document.getElementsByTagName('BODY')[0]).appendChild(s);
    }());
"
    end.to_html
  end

  get %r{^/(\d+)/(\d+)/(\d+)/(.*)$} do |y,m,d,slug|
    articles= @blog.articles
    time=Time.gm(y,m,d,0,0,0)
    articles=articles.find_all do |a|
      # this is a nasty hack to get round DST issues where articles have
      # been written around midnight
      hour_30 = 3600 + 1800
      (a.date >= time-hour_30) && (a.date <= time+86400+hour_30)
    end
    # XXX should check slug
    a=articles[0]
    Page.new(:title=>a.subject,:base=>uri,:blog=>@blog) do
      widget entry(request,a)
      div :id=>:disqus_thread
    end.to_html
  end

  get %r{^/(\d+)/(\d+)/?$} do |y,m|
    articles= @blog.articles
    time=Time.gm(y,m,1,0,0,0)
    time-=2*86400
    end_t=time+35*86400;
    articles=articles.find_all do |a|
      (a.date >= time) && (a.date <= end_t)
    end
    Page.new(:title=>"Month of #{(time+6*86400).strftime('%B %Y')}",
             :base=>uri,:blog=>@blog) do
      articles.each do |art|
        widget entry(request,art,:comments)
      end
      javascript "var disqus_shortname = 'telent';
    (function () {
        var s = document.createElement('script'); s.async = true;
        s.type = 'text/javascript';
        s.src = 'http://' + disqus_shortname + '.disqus.com/count.js';
        (document.getElementsByTagName('HEAD')[0] || document.getElementsByTagName('BODY')[0]).appendChild(s);
    }());
"
    end.to_html
  end

  def find_slug(slug)
    slug=Article.slug_for_title(URI.unescape(slug))
    @blog.articles.find do |art|
      f=art.slug
      f == slug
    end
  end

  # over the years since 2001 the permalink(sic) format has changed:
  # originally /diary/yyyy/mm/#dd, then later /diary/slug.  This should
  # cope with both

  get "/diary/*" do |slug|
    case when slug.empty? then
      redirect url("/"),301
    when a=find_slug(slug) then
      redirect url(a.url),301
    else
      redirect url("/"+slug),301
    end
  end

  get "/diary" do
    redirect url("/"),301
  end

  get %r{\.(ico|png|gif)$} do
    halt 404
  end

  get "/cliki/*" do |page|
    redirect "http://www.cliki.net/"+page
  end

  get "/*" do |slug|
    if a=find_slug(slug) then
      redirect url(a.url),301
    end
  end

  def route_missing
    raise Sinatra::NotFound
  end
end


master=Thin::Prefork.new :app=>Myway.new,
:num_workers=>2,:host=>"0.0.0.0",:port=>4567,
:stderr=>$stderr,:pid_file=>"/tmp/my-way.pid"

def master.reload!
  warn "reloading"
  self.app.blog.rescan
  super
end

Signal.trap("HUP") do
  master.reload!
end

master.run!
