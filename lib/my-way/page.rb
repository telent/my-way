require 'erector'
require 'uri'

class Myway::Page < Erector::Widgets::Page
  needs :blog,:base,:title
  def page_title
    "#{@title} - diary at Telent Netowrks"
  end

  def head_content
    super
    link :rel=>:alternate,:type=>"application/rss+xml",:title=>"RSS Feed",
    :href=>"/news.rss"
  end

  depends_on :css, "/diary.css"
  depends_on :script,%q{
  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-5523795-2']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();
}
  depends_on :js,"http://twitter.com/javascripts/blogger.js"
  depends_on :script,"var old_callback = twitterCallback2;
var twitterCallback2 =function(C) 
{ var A=[];  for(var D=0;D<C.length;D++) { if(C[D].in_reply_to_screen_name == null) A.push(C[D]);  } old_callback(A); }"

  depends_on :script,"
    var disqus_shortname = 'telent';
    var disqus_developer = 1; // XX disable on live site
    (function() {
        var dsq = document.createElement('script'); dsq.type = 'text/javascript'; dsq.async = true;
        dsq.src = 'http://' + disqus_shortname + '.disqus.com/embed.js';
        (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(dsq);
    })();
"

  def body_content 
    recent=@blog.articles
    if recent.length > 10 then recent=recent[-10..-1]  end

    months=Hash.new {|h,k| h[k]=[] }
    @blog.articles.each {|x| 
      d=x.date
      months[d.year] << d.month
    }

    header do
      div :id=>:banner do
        a "diary at Telent Netowrks" , :href=>"/"
      end

      nav do
        div do
          text "I'm Daniel Barlow.  This blog contains geeky stuff about what I do, and in the older entries, what I used to do.  Ruby, Linux, Lisp, Android, thoughts about software development and matters arising.  For my other personality (tech--, skating++), see "
          a "Coruskate", :href=>"http://www.coruskate.net"
        end
        div :id=>:twitter_div do
          h2 do
            a "twitter @telent_net",:href=>"https://twitter.com/telent_net",
            :style=>"text-decoration: none; color: black"
          end
          ul :id=>"twitter_update_list" do
            text "(loading)"
          end
        end
        div do
          h2 "Recently"
          p "Stuff I can probably remember having written"
          ul do
            recent.reverse.each do |a|
              li do
                a a.subject,:href=>a.url
                text  " "+a.date.strftime("%a, %e %b")
              end
            end
          end
        end
        div do
          h2 "Not so recently"
          p "The tenured generations"
          ul do
            months.keys.uniq.sort.reverse.each do |year|
              li do
                b "#{year}: "
                months[year].sort.uniq.map do |m|
                  a Date::ABBR_MONTHNAMES[m],:href=>"/#{year}/#{m}/"
                  text " "
                end
              end
            end
          end
        end
      end
    end
    div :class=>:content do
      super
    end
    rawtext %q{<script type="text/javascript" src="http://twitter.com/statuses/user_timeline/telent_net.json?callback=twitterCallback2&count=5" ></script>}
  end
end
