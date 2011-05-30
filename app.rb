require 'rubygems'
require 'bundler'
Bundler.require(:default, (ENV['RACK_ENV'] ||= :development.to_s).to_sym)
require './lib/pagerank'

CACHE_LIFETIME = 86400 # cache for 1 day
GA_CODE = "<script type=\"text/javascript\">var _gaq = _gaq || [];_gaq.push(['_setAccount', '#GA_ACCOUNT#']);_gaq.push(['_trackPageview']);(function() {var ga = document.createElement('script');ga.type = 'text/javascript'; ga.async = true;ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);})();</script>"

# handle json call
get %r{/json/(.*)} do
  uri = params[:captures].first
  hashed_uri = Digest::MD5.hexdigest(uri)
  content_type :json

  # Setup CouchDB connection
  db = CouchRest.database((ENV['CLOUDANT_URL'] || 'http://127.0.0.1:5984') + '/production')
  
  # call db
  cached_result = db.get(hashed_uri) rescue nil
  if cached_result and cached_result['timestamp'] >= Time.now.to_i - CACHE_LIFETIME
    result = {:rank => cached_result['rank'], :cached => true}
    response['Expires'] = Time.at(cached_result['timestamp'] + CACHE_LIFETIME).httpdate
    etag Digest::MD5.hexdigest("#{result[:rank]}#{uri}")
  else
    # call google
    pr = PageRank.new(uri)
    result = pr.get_rank
    
    # caching
    if result[:rank]
      if cached_result
        db.delete_doc(cached_result)
      end
      db.save_doc({'_id' => hashed_uri, :rank => result[:rank], :timestamp => Time.now.to_i})
      #doc = {'_id' => hashed_uri, :rank => result[:rank], :timestamp => Time.now.to_i}
      #doc['_rev'] = cached_result['_rev'] if cached_result
      #db.save_doc(doc)
      response['Expires'] = (Time.now + CACHE_LIFETIME).httpdate
      etag Digest::MD5.hexdigest("#{result[:rank]}#{uri}")
    else
      result[:fallback] = pr.request_uri
    end
  end
  # deliver result
  result.to_json
end
  
get %r{/(.*)} do
  if request.env['HTTP_USER_AGENT'].include? 'pagerank-client'
    uri = params[:captures].first
    Gabba::Gabba.new(ENV['GA_ACCOUNT'], "pagerank.koeniglich.ch").event("Clients", "Request", request.env['HTTP_USER_AGENT']) if ENV['GA_ACCOUNT']
    redirect PageRank.new(uri).request_uri, 301
  else
    index_html = File.read('./views/index.html')
    index_html.sub!('<!--#GA#-->', GA_CODE.sub('#GA_ACCOUNT#', ENV['GA_ACCOUNT'])) if ENV['GA_ACCOUNT']
    etag Digest::MD5.hexdigest(index_html)
    index_html
  end
end